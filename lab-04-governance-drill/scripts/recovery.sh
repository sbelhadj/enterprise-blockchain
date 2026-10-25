#!/usr/bin/env bash
#
# Listing L4.5: Part E, recovery. CustomsAuthority's peer loses its ledger and
# is rebuilt from a snapshot that two banks produced independently; ImportBank's
# orderer loses its data and rejoins the channel through the participation API.
set -euo pipefail
source "$(dirname "$0")/env.sh"
export VIA=exportbank                 # clients avoid ImportBank's orderer here
height() { peer channel getinfo -c "$CHANNEL" 2>/dev/null |
  grep -o '"height":[0-9]*' | cut -d: -f2; }
status() {  # status ORG: what ORG's orderer says about the channel
  osn "$1" list --channelID "$CHANNEL" 2>/dev/null | sed -n '/^{/,$p' |
    jq -r '"  orderer0.'"$1"': \(.consensusRelation), \(.status),"
      + " height \(.height)"' || echo "  orderer0.$1: not reachable"
}
snap_dir() { echo "/var/hyperledger/snapshots/$1/completed/$CHANNEL/$2"; }

echo "== 1. Two banks snapshot the same block"
use exportbank; B=$(height)
for o in exportbank importbank; do
  use "$o"
  echo "  $o: $(peer snapshot submitrequest -c "$CHANNEL" -b "$B" \
    --peerAddress "$CORE_PEER_ADDRESS" \
    --tlsRootCertFile "$CORE_PEER_TLS_ROOTCERT_FILE" 2>&1 | tail -1)"
done
echo "  block $B: $(ENDORSERS='exportbank importbank' issue_lc "RC-$B-1")"
for o in exportbank importbank; do
  f=$BUILD/snapshots/$o/completed/$CHANNEL/$B/_snapshot_signable_metadata.json
  wait_for 30 test -s "$f"
  echo "  $o: snapshot hash $(sha256sum < "$f" | cut -c1-16)," \
    "last block $(jq .last_block_number "$f")"
done

echo "== 2. peer0.customs loses its ledger and starts empty"
$COMPOSE stop peer0-customs 2>&1 | grep Error || true
$VOLRM "${PROJECT}_peer0.customs.example.com" >/dev/null
$COMPOSE up -d peer0-customs 2>&1 | grep Error || true
wait_for 30 curl -sf http://localhost:9443/healthz
use customs
echo "  channels on peer0.customs: $(peer channel list 2>/dev/null | tail -n +2 |
  wc -l)"

echo "== 3. It joins from ExportBank's snapshot and gets its chaincode back"
peer channel joinbysnapshot --snapshotpath "$(snap_dir exportbank "$B")" 2>&1 |
  grep -o 'Successfully submitted.*' | sed 's/^/  /'
wait_for 30 height
peer lifecycle chaincode install "$BUILD/packages/customs/$CC_LABEL.tgz" 2>&1 |
  grep -o 'Chaincode code package identifier: .\{20\}' | sed 's/^/  /'
echo "  after one more transaction: $(ENDORSERS='exportbank importbank' \
  issue_lc "RC-$B-2")"
sleep 3
echo "  the new LC read on peer0.customs: $(peer chaincode query -C "$CHANNEL" \
  -n "$CC" -c "$(cc_args ReadLC "RC-$B-2")" 2>/dev/null | jq -r .status)"
echo "  block 1 from peer0.customs: $(peer chaincode query -C "$CHANNEL" -n qscc \
  -c "$(jq -cn --arg c "$CHANNEL" '{Args: ["GetBlockByNumber", $c, "1"]}')" 2>&1 |
  grep -o 'First available block = \[[0-9]*\]')"

echo "== 4. orderer0.importbank loses its data and tries to rejoin as it was"
IB=orderer0.importbank.example.com
wipe() { $COMPOSE stop orderer0-importbank 2>&1 | grep Error || true
  $VOLRM "${PROJECT}_$IB" >/dev/null
  $COMPOSE up -d orderer0-importbank 2>&1 | grep Error || true
  wait_for 30 curl -sf http://localhost:8444/healthz; }
wipe
fetch_config "$W/c.json"                         # the latest config block
osn importbank join --channelID "$CHANNEL" --config-block "$W/config.pb" |
  grep -o 'Status: [0-9]*' | sed 's/^/  join: /'
sleep 5
$COMPOSE logs orderer0-importbank 2>&1 | grep -o 'PANI.*' | head -1 |
  grep -o -E 'tocommit.*\]|Was the raft[^?]*\?' | sed 's/^/  /'
for o in importbank exportbank; do status "$o"; done

echo "== 5. It leaves the consenter set, then rejoins empty as a follower"
jq -c --arg h "$IB" '.channel_group.groups.Orderer.values.ConsensusType.value
  .metadata.consenters[] | select(.host == $h)' "$W/c.json" > "$W/ib.json"
jq --arg h "$IB" '.channel_group.groups.Orderer.values.ConsensusType.value.metadata
  .consenters |= map(select(.host != $h))' "$W/c.json" > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/u4.pb"
sign_and_submit "$W/u4.pb" importbank shippingline exportbank   # 3 of 4
wipe
fetch_config "$W/c.json"                         # importbank is not a consenter
osn importbank join --channelID "$CHANNEL" --config-block "$W/config.pb" |
  grep -o 'Status: [0-9]*' | sed 's/^/  join: /'
sleep 5; status importbank

echo "== 6. It is added back as a consenter"
jq --slurpfile e "$W/ib.json" '.channel_group.groups.Orderer.values.ConsensusType
  .value.metadata.consenters += $e' "$W/c.json" > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/u5.pb"
sign_and_submit "$W/u5.pb" importbank shippingline exportbank
sleep 8
echo "  after one more transaction: $(ENDORSERS='exportbank importbank' \
  issue_lc "RC-$B-3")"
sleep 3
for o in exportbank importbank shippingline; do status "$o"; done

echo "== 7. Every peer at the same height with the same last block"
heights
