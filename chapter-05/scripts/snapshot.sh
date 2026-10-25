#!/usr/bin/env bash
#
# Listing 5.13: take a ledger snapshot on peer0.exportbank and start a second
# ExportBank peer, peer1, from it instead of replaying every block since block 0.
set -euo pipefail
source "$(dirname "$0")/env.sh"
use exportbank
TLS=(--peerAddress localhost:7051 --tlsRootCertFile "$CORE_PEER_TLS_ROOTCERT_FILE")
HOST_DIR=$CH5/snapshots/peer0/completed/$CHANNEL         # as the host sees it
PEER_DIR=/var/hyperledger/snapshots/peer0/completed/$CHANNEL   # as the peers see it

echo "== 1. Request a snapshot at the next committed block"
peer snapshot submitrequest -c "$CHANNEL" -b 0 "${TLS[@]}" 2>&1 |
  grep -v InitCmdFactory
for i in $(seq 30); do
  last=$(ls "$HOST_DIR" 2>/dev/null | sort -n | tail -1)
  [ -n "$last" ] && break; sleep 1
done
echo "snapshot of block $last:"
ls "$HOST_DIR/$last"
jq -c '{channel_name, last_block_number, last_block_hash: .last_block_hash[0:16]}' \
  "$HOST_DIR/$last/_snapshot_signable_metadata.json"

echo "== 2. Start peer1 and join it from the snapshot"
$COMPOSE up -d peer1-exportbank 2>&1 | grep -E 'Started|Error' || true
for i in $(seq 30); do
  curl -s localhost:7445/healthz | grep -q OK && break; sleep 1
done
use exportbank admin peer1
peer channel joinbysnapshot --snapshotpath "$PEER_DIR/$last" 2>&1 |
  grep -o 'Successfully submitted.*'
for i in $(seq 30); do
  peer channel getinfo -c "$CHANNEL" >/dev/null 2>&1 && break; sleep 1
done
peer lifecycle chaincode install "$CH5/packages/exportbank/lc_1.1.tgz" 2>&1 |
  grep -o 'Chaincode code package identifier: .*'

echo "== 3. One more transaction, then compare the two peers"
"$CH5/scripts/lc-demo.sh" LC-2026-102 | sed -n 1,2p
sleep 3
for p in peer0 peer1; do
  use exportbank user1 $p
  height=$(peer channel getinfo -c "$CHANNEL" 2>/dev/null |
           sed 's/.*"height":\([0-9]*\).*/\1/')
  echo "$p: height $height, $(lc_query ReadLC LC-2026-102 |
    jq -r '"LC-2026-102 is " + .status')"
done

echo "== 4. What peer1 does not have: the blocks before the snapshot"
use exportbank admin peer1
peer chaincode query -C "$CHANNEL" -n qscc \
  -c "$(jq -cn --arg ch "$CHANNEL" '{Args: ["GetBlockByNumber", $ch, "1"]}')" 2>&1 |
  grep -o 'cannot serve block.*\]'
