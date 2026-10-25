#!/usr/bin/env bash
#
# Appendix A, Exercise 1.3: Experiment A (one endorsement where the policy needs
# two) and Experiment B (time from submission to commit, five times). Run from
# fabric-samples/test-network at the end of Chapter 1.
set -euo pipefail
source "$(dirname "$0")/../../chapter-01/org1-env.sh"
ORGS=${PWD}/organizations
ORDERER_CA=$ORGS/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
P=$ORGS/peerOrganizations
ORG1_TLS=$P/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
ORG2_TLS=$P/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem
create() {  # create ASSET PEER_ARGS...: CreateAsset, waiting for the commit event
  local args; args=$(jq -cn --arg id "$1" \
    '{function: "CreateAsset", Args: [$id, "red", "5", "Imen", "300"]}'); shift
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride \
    orderer.example.com --tls --cafile "$ORDERER_CA" -C mychannel -n basic \
    "$@" -c "$args" --waitForEvent 2>&1 |
    grep -o "committed with status ([A-Z_]*)" | head -1
}
ORG1=(--peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS")
ORG2=(--peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS")

echo "== Experiment A: asset8 endorsed by Org1's peer only"
echo "  $(create asset8 "${ORG1[@]}")"
echo "  asset8 on Org1's peer afterwards: $(peer chaincode query -C mychannel \
  -n basic -c '{"Args":["AssetExists","asset8"]}' 2>/dev/null)"

echo "== Experiment B: five transactions endorsed by both peers, timed"
for i in 1 2 3 4 5; do
  t0=$(date +%s%N)
  r=$(create "asset1$i" "${ORG1[@]}" "${ORG2[@]}")
  echo "  asset1$i: $r in $(( ($(date +%s%N) - t0) / 1000000 )) ms"
done
echo "  BatchTimeout in configtx/configtx.yaml:" \
  "$(grep -m1 'BatchTimeout' configtx/configtx.yaml | awk '{print $2}')"
