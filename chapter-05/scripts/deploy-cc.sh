#!/usr/bin/env bash
#
# Listing 5.10: deploy the letter of credit chaincode as a service. Each organization
# packages a connection.json that points at its own chaincode server, installs it,
# starts that server with the package ID and approves the definition; then one
# administrator commits it. Usage: deploy-cc.sh [ORG...] (default: both banks)
set -euo pipefail
source "$(dirname "$0")/env.sh"
ORGS=${*:-exportbank importbank}
LABEL=lc_1.1 VERSION=1.1 SEQUENCE=${SEQUENCE:-1}
CC_SRC=$CH5/../chapter-03/lc-chaincode      # META-INF/ holds the CouchDB index

package() {  # package: a CCaaS package with metadata and connection details only
  local dir=$CH5/packages/$ORG
  rm -rf "$dir"; mkdir -p "$dir/src"
  jq -n --arg addr "lc.$DOMAIN:$((BASE + 99))" \
    --rawfile root "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    '{address: $addr, dial_timeout: "10s", tls_required: true,
      client_auth_required: false, root_cert: $root}' > "$dir/src/connection.json"
  cp -r "$CC_SRC/META-INF" "$dir/src/"
  tar -C "$dir/src" -czf "$dir/code.tar.gz" connection.json META-INF
  jq -n --arg label "$LABEL" '{type: "ccaas", label: $label}' > "$dir/metadata.json"
  tar -C "$dir" -czf "$dir/$LABEL.tgz" metadata.json code.tar.gz
  echo "$dir/$LABEL.tgz"
}

for o in $ORGS; do
  use $o
  echo "== $MSP"
  pkg=$(package)
  peer lifecycle chaincode install "$pkg" 2>&1 |
    grep -o 'Chaincode code package identifier: .*'
  id=$(peer lifecycle chaincode calculatepackageid "$pkg")
  # start this organization's chaincode server with the ID its peer will ask for
  env "LC_PACKAGE_ID_${o^^}=$id" $COMPOSE up -d "lc-$o" 2>&1 |
    grep -E 'Started|Error' || true
  peer lifecycle chaincode approveformyorg -o "$ORDERER" --tls \
    --cafile "$ORDERER_CA" -C "$CHANNEL" -n lc -v "$VERSION" \
    --sequence "$SEQUENCE" --package-id "$id" 2>&1 |
    grep -o "txid \[.*\] committed with status (.*)"
done

# an organization that joins later approves the definition that is already committed
[ -n "${NO_COMMIT:-}" ] && exit 0
use exportbank
peer lifecycle chaincode checkcommitreadiness -C "$CHANNEL" -n lc -v "$VERSION" \
  --sequence "$SEQUENCE"
PEERS=()
for o in exportbank importbank; do
  org $o; PEERS+=(--peerAddresses "localhost:$((BASE + 51))"
                  --tlsRootCertFiles "$ORGDIR/msp/tlscacerts/tlsca.pem")
done
use exportbank
peer lifecycle chaincode commit -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL" -n lc -v "$VERSION" --sequence "$SEQUENCE" "${PEERS[@]}" 2>&1 |
  grep -o "txid \[.*\] committed with status (.*) at .*"
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n lc
