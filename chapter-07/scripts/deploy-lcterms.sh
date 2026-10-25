#!/usr/bin/env bash
#
# Listing 7.5: deploy lcterms with its collection. Every organization installs
# it and runs its own server, CustomsAuthority included, so that its peer can
# check hashes.
set -euo pipefail
source "$(dirname "$0")/env.sh"
LABEL=lcterms_1.0 COLLECTIONS=$CH7/lcterms/collections.json
for o in exportbank importbank customs; do
  use $o
  echo "== $MSP"
  tls_cert $o lcterms "lcterms.$DOMAIN,localhost"
  dir=$CH5/packages/lcterms-$o; rm -rf "$dir"; mkdir -p "$dir"
  jq -n --arg addr "lcterms.$DOMAIN:$((BASE + 98))" \
    --rawfile root "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    '{address: $addr, dial_timeout: "10s", tls_required: true, root_cert: $root}' \
    > "$dir/connection.json"
  tar -C "$dir" -czf "$dir/code.tar.gz" connection.json
  jq -n --arg l "$LABEL" '{type: "ccaas", label: $l}' > "$dir/metadata.json"
  tar -C "$dir" -czf "$dir/$LABEL.tgz" metadata.json code.tar.gz
  peer lifecycle chaincode install "$dir/$LABEL.tgz" >/dev/null 2>&1
  id=$(peer lifecycle chaincode calculatepackageid "$dir/$LABEL.tgz")
  env "LCTERMS_PACKAGE_ID_${o^^}=$id" $COMPOSE up -d "lcterms-$o" 2>&1 |
    grep -E 'Started|Error' || true
  peer lifecycle chaincode approveformyorg -o "$ORDERER" --tls \
    --cafile "$ORDERER_CA" -C "$CHANNEL" -n lcterms -v 1.0 --sequence 1 \
    --package-id "$id" --collections-config "$COLLECTIONS" 2>&1 |
    grep -o "committed with status (.*)"
done
use exportbank
peer lifecycle chaincode commit -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL" -n lcterms -v 1.0 --sequence 1 --collections-config "$COLLECTIONS" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORDERER_CA" \
  --peerAddresses localhost:8051 \
  --tlsRootCertFiles "$CH5/organizations/importbank/msp/tlscacerts/tlsca.pem" 2>&1 |
  grep -o "committed with status (.*) at .*"
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n lcterms | tail -1
