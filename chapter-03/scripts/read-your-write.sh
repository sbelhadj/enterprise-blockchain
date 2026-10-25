#!/usr/bin/env bash
#
# The experiment of Section 3.4.2: deploy the probe chaincode (Listing 3.8), then ask it.
# Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
./network.sh deployCC -ccn probe -ccp "$HERE/../probe-chaincode" -ccl javascript \
  > /dev/null 2>&1
source "$HERE/env.sh" org1
PEERS=(--peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS"
       --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS")

echo "== 1. Evaluate on a fresh key: nothing is committed"
peer chaincode query -C mychannel -n probe -c '{"Args":["ReadYourWrite","k1"]}'
echo "== 2. Submit the same call, so the write to k1 is committed"
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C mychannel -n probe "${PEERS[@]}" \
  -c '{"Args":["ReadYourWrite","k1"]}' --waitForEvent 2>&1 | grep -o 'status:200 payload:.*'
echo "== 3. Evaluate again: reads see the committed value, never this transaction's write"
peer chaincode query -C mychannel -n probe -c '{"Args":["ReadYourWrite","k1"]}'
