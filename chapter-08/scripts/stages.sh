#!/usr/bin/env bash
#
# Listing 8.4: where the time goes, from the nodes' own metrics.
#   stages.sh RATE SECONDS
# Reads the operations endpoints of ImportBank's peer and orderer before and
# after a load run and prints what the run cost each stage.
set -euo pipefail
RATE=${1:-50} SECONDS_=${2:-20}
LOAD=$(cd "$(dirname "$0")/../load" && pwd)
PEER=localhost:8443 ORDR=localhost:8444    # operations ports (Chapter 5, Table 5.1)

snap() {  # snap FILE: the _sum and _count lines of both endpoints, one value each
  { curl -s --noproxy '*' "http://$PEER/metrics" | sed 's/^/peer_/'
    curl -s --noproxy '*' "http://$ORDR/metrics" | sed 's/^/ord_/'
  } | grep -E '_(sum|count)(\{[^}]*\})? ' | grep -v ' le=' > "$1"
}
d() {  # d NAME LABEL_FILTER: the change in a metric between the two snapshots
  awk -v m="$1" -v f="$2" '
    index($1, m) == 1 && index($1, f) { v[FILENAME] += $2 }
    END { printf "%.6f", v[ARGV[2]] - v[ARGV[1]] }' "$B" "$A"
}

B=$(mktemp) A=$(mktemp); trap 'rm -f "$B" "$A" "$B.pb"' EXIT
snap "$B"
(cd "$LOAD" && node dist/load.js stages "$RATE" "$SECONDS_" >/dev/null)
snap "$A"
source "$(dirname "$0")/../../chapter-05/scripts/env.sh"; use importbank
peer channel fetch newest "$B.pb" -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" >/dev/null 2>&1
n=$(configtxlator proto_decode --type common.Block --input "$B.pb" |
  jq '.data.data | length')
echo "newest block: $n transactions, $(( $(stat -c %s "$B.pb") / n )) bytes each"

tx=$(d peer_ledger_transaction_count 'chaincode="lc:')
blocks=$(d peer_ledger_statedb_commit_time_count lcchannel)
props=$(d peer_endorser_proposal_duration_count 'chaincode="lc"')
awk -v tx="$tx" -v b="$blocks" -v p="$props" \
  -v endorse="$(d peer_endorser_proposal_duration_sum 'chaincode="lc"')" \
  -v bvalid="$(d ord_broadcast_validate_duration_sum ENDORSER)" \
  -v fsync="$(d ord_etcd_disk_wal_fsync_duration_seconds_sum '')" \
  -v nfsync="$(d ord_etcd_disk_wal_fsync_duration_seconds_count '')" \
  -v valid="$(d peer_gossip_privdata_validation_duration_sum lcchannel)" \
  -v commit="$(d peer_gossip_privdata_commit_block_duration_sum lcchannel)" \
  -v state="$(d peer_ledger_statedb_commit_time_sum lcchannel)" 'BEGIN {
  printf "%d transactions in %d blocks, %.1f per block\n", tx, b, tx / b
  printf "peer   endorse one proposal (chaincode run)   %7.2f ms\n", 1000*endorse/p
  printf "orderer check one envelope on arrival       %7.2f ms\n", 1000*bvalid/tx
  printf "orderer write-ahead log fsync, per call     %7.2f ms\n", 1000*fsync/nfsync
  printf "peer   validate one block                   %7.2f ms\n", 1000*valid/b
  printf "peer   commit one block (of which state DB) %7.2f ms (%.2f ms)\n",
    1000*commit/b, 1000*state/b
  printf "peer   validate and commit, per transaction %7.2f ms\n",
    1000*(valid+commit)/tx }'
