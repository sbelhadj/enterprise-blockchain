#!/usr/bin/env bash
#
# Appendix A, Exercise 2.4: basic deployed again as basicand with an AND policy,
# then CreateAsset endorsed by Org1's peer only. Run from
# fabric-samples/test-network.
set -euo pipefail
source "$(dirname "$0")/../../chapter-01/org1-env.sh"
P=${PWD}/organizations/peerOrganizations
O=${PWD}/organizations/ordererOrganizations/example.com
ORDERER_CA=$O/tlsca/tlsca.example.com-cert.pem
echo "== Deploy basicand"
./network.sh deployCC -ccn basicand \
  -ccp ../asset-transfer-basic/chaincode-typescript -ccl typescript \
  -ccep "AND('Org1MSP.peer','Org2MSP.peer')" >/dev/null 2>&1
peer lifecycle chaincode querycommitted -C mychannel -n basicand -O json |
  jq -r '"basicand \(.version), sequence \(.sequence), approved by " +
    ([.approvals | to_entries[] | select(.value) | .key] | join(" "))'
echo "== CreateAsset on basicand, endorsed by peer0.org1 only"
R=$(peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride \
  orderer.example.com --tls --cafile "$ORDERER_CA" -C mychannel -n basicand \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "$P/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem" \
  -c '{"function":"CreateAsset","Args":["asset20","green","5","Sami","100"]}' \
  --waitForEvent 2>&1 || true)
grep -o 'committed with status ([A-Z_]*)' <<< "$R" | head -1
echo "== The orderer put it in a block; the peer recorded why it is invalid"
WORK=$(cd "$(dirname "$0")/../.." && pwd)/work
source "$(dirname "$0")/../../chapter-02/ledger-lib.sh"
show_tx "$(sed -n 's/.*txid \[\([0-9a-f]*\)\].*/\1/p' <<< "$R" | head -1)" |
  head -4 2>/dev/null
