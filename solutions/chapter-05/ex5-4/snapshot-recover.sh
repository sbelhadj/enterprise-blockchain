#!/usr/bin/env bash
#
# Appendix A, Exercise 5.4: two banks snapshot the same block and compare the
# metadata; then peer1.exportbank loses its volume and comes back from a fresh
# snapshot. Run after Listing 5.13 (peer1 running).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../../../chapter-05/scripts/env.sh"
COMPOSE="$COMPOSE -f $HERE/compose-snapshots.yaml"
VOLRM=${VOLRM:-docker volume rm}
declare -A DIR=([exportbank]=peer0 [importbank]=importbank)
height() { peer channel getinfo -c "$CHANNEL" 2>/dev/null |
  sed 's/.*"height":\([0-9]*\).*/\1/'; }
probe() {  # probe LABEL: peer1's height and a letter of credit it reads
  use exportbank user1 peer1
  echo "  $1: peer1 height $(height || echo none)," \
    "LC-2026-102 $(lc_query ReadLC LC-2026-102 | jq -r .status 2>/dev/null ||
    echo unreadable)"
}

echo "== 1. ImportBank's peer gets a snapshot folder (configuration change)"
$COMPOSE up -d peer0-importbank 2>&1 | grep Error || true
for i in $(seq 30); do curl -sf localhost:8443/healthz >/dev/null && break; sleep 1
done

echo "== 2. Both banks request a snapshot of the same block"
use exportbank; B=$(height)
for o in exportbank importbank; do
  use "$o"
  echo "  $o: $(peer snapshot submitrequest -c "$CHANNEL" -b "$B" \
    --peerAddress "$CORE_PEER_ADDRESS" \
    --tlsRootCertFile "$CORE_PEER_TLS_ROOTCERT_FILE" 2>&1 | tail -1)"
done
echo "  block $B: $("$CH5/scripts/lc-demo.sh" LC-2026-103 |
  grep -o 'committed with status ([A-Z_]*)' | head -1)"
for o in exportbank importbank; do
  f=$CH5/snapshots/${DIR[$o]}/completed/$CHANNEL/$B/_snapshot_signable_metadata.json
  for i in $(seq 30); do [ -s "$f" ] && break; sleep 1; done
  echo "  $o: $(jq -c '{last_block_number,
    last_block_hash: .last_block_hash[0:16]}' "$f")"
  echo "  $o: sha256 of the metadata file $(sha256sum < "$f" | cut -c1-16)"
done
m() {  # m DIR: the metadata file of the snapshot of block B in DIR
  echo "$CH5/snapshots/$1/completed/$CHANNEL/$B/_snapshot_signable_metadata.json"; }
cmp -s "$(m peer0)" "$(m importbank)" &&
  echo "  the two metadata files are identical, byte for byte"

echo "== 3. peer1.exportbank loses its volume"
probe before
$COMPOSE stop peer1-exportbank 2>&1 | grep Error || true
$VOLRM lcnet_peer1.exportbank.example.com >/dev/null
$COMPOSE up -d peer1-exportbank 2>&1 | grep Error || true
for i in $(seq 30); do curl -sf localhost:7445/healthz >/dev/null && break; sleep 1
done
probe "after the loss"

echo "== 4. It joins from ImportBank's snapshot and gets its package back"
use exportbank admin peer1
peer channel joinbysnapshot \
  --snapshotpath "/var/hyperledger/snapshots/importbank/completed/$CHANNEL/$B" \
  2>&1 | grep -o 'Successfully submitted.*' | sed 's/^/  /'
for i in $(seq 30); do height >/dev/null && break; sleep 1; done
peer lifecycle chaincode install "$CH5/packages/exportbank/lc_1.1.tgz" 2>&1 |
  grep -o 'Chaincode code package identifier: .\{20\}' | sed 's/^/  /'
sleep 3
probe "after recovery"
use exportbank user1; echo "  peer0 height $(height), for comparison"
