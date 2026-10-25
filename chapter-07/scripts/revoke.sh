#!/usr/bin/env bash
#
# Listing 7.8: a revocation drill. ExportBank enrolls trader7, revokes the
# certificate, and puts the new certificate revocation list (CRL) into the
# channel configuration.
# The revocation takes effect only at the last step.
set -euo pipefail
source "$(dirname "$0")/env.sh"
org exportbank
W=$CH5/channel-artifacts/revoke; rm -rf "$W"; mkdir -p "$W"
export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
CA=(--caname ca-exportbank --tls.certfiles "$ORGDIR/ca/ca-cert.pem")
try() {  # try WHO: WHO writes a note to ExportBank's implicit collection
  use exportbank "$1"
  local note
  note=$(jq -cn '{note: ("checked" | @base64)}')
  echo "$1: $(terms_submit --peerAddresses localhost:7051 --tlsRootCertFiles \
    "$ORGDIR/msp/tlscacerts/tlsca.pem" -- PutCreditNote "LC-2026-101" "$note" |
    sed 's/.*\(access denied: .*\]\) - .*/\1/')"
}

echo "== 1. Enroll trader7, who can transact"
s=$(openssl rand -hex 16)
fabric-ca-client register "${CA[@]}" -M "$ORGDIR/ca-admin/msp" \
  -u https://localhost:7054 --id.name trader7 --id.secret "$s" --id.type client \
  >/dev/null 2>&1
fabric-ca-client enroll "${CA[@]}" -u "https://trader7:$s@localhost:7054" \
  -M "$ORGDIR/trader7/msp" >/dev/null 2>&1
cp "$ORGDIR/msp/config.yaml" "$ORGDIR/trader7/msp/"
openssl x509 -in "$ORGDIR/trader7/msp/signcerts/cert.pem" -noout -serial
try trader7

echo "== 2. Revoke the certificate and generate a CRL"
fabric-ca-client revoke "${CA[@]}" -M "$ORGDIR/ca-admin/msp" -e trader7 \
  -r keycompromise --gencrl >/dev/null 2>&1
CRL=$ORGDIR/ca-admin/msp/crls/crl.pem
openssl crl -in "$CRL" -noout -text |
  grep -E 'Serial Number|Revocation Date' | sed 's/^ *//' 
try trader7

echo "== 3. ExportBank puts the CRL into its MSP in the channel configuration"
use exportbank
peer channel fetch config "$W/config.pb" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" -c "$CHANNEL" >/dev/null 2>&1
configtxlator proto_decode --type common.Block --input "$W/config.pb" |
  jq '.data.data[0].payload.data.config' > "$W/config.json"
M='groups.ExportBankMSP.values.MSP.value.config.revocation_list'
jq --arg crl "$(base64 -w0 < "$CRL")" \
  ".channel_group.groups.Application.$M = [\$crl] |
   .channel_group.groups.Orderer.$M = [\$crl]" "$W/config.json" > "$W/modified.json"
for f in config modified; do
  configtxlator proto_encode --type common.Config --input "$W/$f.json" \
    --output "$W/$f.pbc"
done
configtxlator compute_update --channel_id "$CHANNEL" --original "$W/config.pbc" \
  --updated "$W/modified.pbc" |
  configtxlator proto_decode --type common.ConfigUpdate |
  jq --arg ch "$CHANNEL" '{payload: {header: {channel_header: {channel_id: $ch,
    type: 2}}, data: {config_update: .}}}' |
  configtxlator proto_encode --type common.Envelope --output "$W/update.pb"
peer channel update -f "$W/update.pb" -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" 2>&1 | grep -o 'Successfully submitted channel update'
sleep 3

echo "== 4. The same calls again"
try trader7
try user1
$COMPOSE logs peer0-exportbank 2>&1 | grep -o \
  'could not validate identity against certification chain: [A-Za-z ]* revoked' |
  tail -1 | sed 's/^/peer log: /'
