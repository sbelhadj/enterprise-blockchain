#!/usr/bin/env bash
#
# Appendix A, Exercise 3.5: release version 1.2 at sequence 3, recording each
# organization's approval with checkcommitreadiness. Run from
# fabric-samples/test-network, after chapter-03/scripts/upgrade-lc.sh.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ENV=$HERE/../../chapter-03/scripts/env.sh
WORK=$(cd "$HERE/../.." && pwd)/work PKG=$(cd "$HERE/../.." && pwd)/work/lc-1.2
DEF=(--channelID mychannel --name lc --version 1.2 --sequence 3)

echo "== Build and package version 1.2 (indexes: indexStatus and indexAmount)"
rm -rf "$PKG" && mkdir -p "$PKG"
for f in src META-INF package.json package-lock.json tsconfig.json; do
  cp -r "$HERE/lc-chaincode/$f" "$PKG/"
done
( cd "$PKG" && npm ci --no-audit --no-fund --loglevel=error >/dev/null && npx tsc &&
  rm -rf node_modules src tsconfig.json )
source "$ENV" org1
peer lifecycle chaincode package "$WORK/lc_1.2.tar.gz" --path "$PKG" --lang node \
  --label lc_1.2
PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid "$WORK/lc_1.2.tar.gz")
ORDERER=(-o localhost:7050 --ordererTLSHostnameOverride orderer.example.com
         --tls --cafile "$ORDERER_CA")
readiness() {
  peer lifecycle chaincode checkcommitreadiness "${DEF[@]}" -O json 2>/dev/null |
    jq -c '"  readiness: \(.approvals)"' -r
}
echo "  before any approval"; readiness
for org in org1 org2; do
  source "$ENV" $org
  peer lifecycle chaincode install "$WORK/lc_1.2.tar.gz" 2>&1 |
    grep -o 'Chaincode code package identifier: .*' | cut -c1-60 | sed 's/^/  /'
  peer lifecycle chaincode approveformyorg "${ORDERER[@]}" "${DEF[@]}" \
    --package-id "$PACKAGE_ID" 2>&1 | grep -o 'committed with status (.*)' |
    sed "s/^/  $CORE_PEER_LOCALMSPID approves: /"
  readiness
done
echo "== Commit, endorsed by both organizations"
peer lifecycle chaincode commit "${ORDERER[@]}" "${DEF[@]}" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" 2>&1 |
  grep -o 'committed with status (.*) at localhost:[0-9]*' | sed 's/^/  /'
peer lifecycle chaincode querycommitted --channelID mychannel --name lc -O json |
  jq -r '"  committed: version \(.version), sequence \(.sequence)"'
