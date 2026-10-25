#!/usr/bin/env bash
#
# submit.sh CHANNEL ORDERER_NAME ORDERER_PORT ASSET: create one asset through
# the given orderer and report how long the commit took.
# Run from fabric-samples/test-network.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../../chapter-03/scripts/env.sh" org1
channel=$1 orderer=$2 port=$3 asset=$4
args=$(printf '{"function":"CreateAsset","Args":["%s","blue","1","ExportBank","1"]}' \
  "$asset")
start=$(date +%s.%N)
out=$(timeout 45 peer chaincode invoke -o "localhost:$port" \
  --ordererTLSHostnameOverride "$orderer.example.com" --tls --cafile "$ORDERER_CA" \
  -C "$channel" -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" \
  -c "$args" --waitForEvent 2>&1)
rc=$?
secs=$(echo "$(date +%s.%N) - $start" | bc)
result=$(grep -o 'committed with status ([A-Z_]*)' <<< "$out" | head -1)
[ -z "$result" ] &&
  result=$(grep -m1 -o 'Error: .*' <<< "$out" | sed 's/ - proposal response.*//')
[ $rc -eq 124 ] && result="no answer within 45 s"
printf '%s via %s: %s (%.1f s)\n' "$asset" "$orderer" "$result" "$secs"
