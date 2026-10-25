#!/usr/bin/env bash
#
# Listing 3.19: the chaincode lifecycle, step by step. Run from fabric-samples/test-network:
#   deploy-lc.sh 1.0 1     first deployment
#   deploy-lc.sh 1.1 2     upgrade (Section 3.10.3)
# The repository holds version 1.1. For 1.0 the script removes the code between the
# "v1.1 begin" and "v1.1 end" markers, so you can replay the upgrade exactly.
set -euo pipefail
VERSION=${1:?usage: deploy-lc.sh VERSION SEQUENCE}
SEQUENCE=${2:?usage: deploy-lc.sh VERSION SEQUENCE}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/../lc-chaincode
WORK=$(cd "$HERE/../.." && pwd)/work
PKG=$WORK/lc-$VERSION

echo "== 1. Build: compiled code, manifest, lock file and CouchDB indexes only"
rm -rf "$PKG" && mkdir -p "$PKG"
for f in src META-INF package.json package-lock.json tsconfig.json; do
  cp -r "$SRC/$f" "$PKG/"
done
if [ "$VERSION" = "1.0" ]; then
  sed -i '/\/\/ v1.1 begin/,/\/\/ v1.1 end/d' "$PKG/src/lcContract.ts"
fi
( cd "$PKG" && npm ci --no-audit --no-fund --loglevel=error && npx tsc &&
  rm -rf node_modules src tsconfig.json )
find "$PKG" -type f | sed "s#^$PKG/##" | sort

echo "== 2. Package"
source "$HERE/env.sh" org1
peer lifecycle chaincode package "$WORK/lc_$VERSION.tar.gz" --path "$PKG" --lang node \
  --label "lc_$VERSION"
PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid "$WORK/lc_$VERSION.tar.gz")
echo "package ID: $PACKAGE_ID"

ORDERER=(-o localhost:7050 --ordererTLSHostnameOverride orderer.example.com
         --tls --cafile "$ORDERER_CA")
for org in org1 org2; do
  echo "== 3. Install on peer0.$org"
  source "$HERE/env.sh" $org
  peer lifecycle chaincode install "$WORK/lc_$VERSION.tar.gz"
  echo "== 4. Approve for $CORE_PEER_LOCALMSPID"
  peer lifecycle chaincode approveformyorg "${ORDERER[@]}" --channelID mychannel --name lc \
    --version "$VERSION" --package-id "$PACKAGE_ID" --sequence "$SEQUENCE"
  peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name lc \
    --version "$VERSION" --sequence "$SEQUENCE"
done

echo "== 5. Commit, endorsed by both organizations"
peer lifecycle chaincode commit "${ORDERER[@]}" --channelID mychannel --name lc \
  --version "$VERSION" --sequence "$SEQUENCE" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS"
peer lifecycle chaincode querycommitted --channelID mychannel --name lc
