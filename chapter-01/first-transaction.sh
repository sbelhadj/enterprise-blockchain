#!/usr/bin/env bash
#
# Listing 1.4: submit one transaction as Org1 and find it on the ledger.
# Run from fabric-samples/test-network after Listings 1.2 and 1.3.
set -euo pipefail
source "$(dirname "$0")/org1-env.sh"
# Scratch files go to work/ in the companion repository (ignored by Git), not into fabric-samples
WORK=$(cd "$(dirname "$0")/.." && pwd)/work; mkdir -p "$WORK"

ORGS=${PWD}/organizations
ORDERER_CA=$ORGS/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
ORG1_TLS=$ORGS/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
ORG2_TLS=$ORGS/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem

# 1. Create one asset. The endorsement policy needs both organizations, so we ask both peers.
#    --waitForEvent makes the CLI wait until the peers report the transaction committed.
peer chaincode invoke -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" \
  -c '{"function":"CreateAsset","Args":["asset7","blue","20","ExportBank","950"]}' \
  --waitForEvent

# 2. Fetch the newest block and print its number and the transaction ID it carries
peer channel fetch newest "$WORK/newest.block" -c mychannel -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA"
configtxlator proto_decode --type common.Block --input "$WORK/newest.block" |
  jq '{block: .header.number,
       tx_id: .data.data[0].payload.header.channel_header.tx_id}'

# 3. Read the asset back from Org1's world state
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset7"]}'
