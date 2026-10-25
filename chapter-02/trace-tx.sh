#!/usr/bin/env bash
#
# Listing 2.3: transfer asset7 and read back what each stage of execute-order-validate left behind.
# Run from fabric-samples/test-network after Chapter 1.
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

# Execute and order: endorsed by both peers, then submitted to the ordering service
peer chaincode invoke -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" \
  -c '{"function":"TransferAsset","Args":["asset7","ImportBank"]}' \
  --waitForEvent 2>&1 | tee "$WORK/invoke.log"
TX=$(sed -n 's/.*txid \[\([0-9a-f]*\)\].*/\1/p' "$WORK/invoke.log" | head -1)

# Validate: what peer0.org1 recorded for this transaction
show_tx "$TX"
