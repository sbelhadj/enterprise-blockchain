#!/usr/bin/env bash
#
# Listing 2.4: two transfers of the same asset, endorsed against the same version.
# Both are ordered; only the first one to be validated can be VALID.
# Run from fabric-samples/test-network after Listing 2.3.
set -euo pipefail
HERE=$(dirname "$0")
source "$HERE/../chapter-01/org1-env.sh"
source "$HERE/ledger-lib.sh"
# Scratch files go to work/ in the companion repository (ignored by Git), not into fabric-samples
WORK=$(cd "$HERE/.." && pwd)/work; mkdir -p "$WORK"
ORGS=${PWD}/organizations
ORDERER_CA=$ORGS/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
ORG1_TLS=$ORGS/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
ORG2_TLS=$ORGS/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem

transfer() { # NEW_OWNER LOGFILE
  peer chaincode invoke -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" -C mychannel -n basic \
    --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" \
    -c "{\"function\":\"TransferAsset\",\"Args\":[\"asset7\",\"$1\"]}" \
    --waitForEvent > "$2" 2>&1 || true
}

# Start both transfers at the same moment; the ordering service batches for up to 2 seconds,
# so both reach the same block
transfer CustomsAuthority "$WORK/a.log" &
transfer ShippingLine "$WORK/b.log" &
wait
grep -h -E 'committed with status|Error' "$WORK/a.log" "$WORK/b.log"

for log in "$WORK/a.log" "$WORK/b.log"; do
  TX=$(sed -n 's/.*txid \[\([0-9a-f]*\)\].*/\1/p' "$log" | head -1)
  echo "== $(basename "$log"): $TX"
  show_tx "$TX"
done
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset7"]}'
