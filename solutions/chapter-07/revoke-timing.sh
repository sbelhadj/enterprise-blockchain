#!/usr/bin/env bash
#
# Appendix A, Exercise 7.3: Listing 7.8 for an ImportBank user, timed. The
# interval runs from the revocation at the CA to the committed channel update.
set -euo pipefail
source "$(dirname "$0")/../../chapter-07/scripts/env.sh"
org importbank
W=$CH5/channel-artifacts/ex7-3; rm -rf "$W"; mkdir -p "$W"
export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
CA=(--caname ca-importbank --tls.certfiles "$ORGDIR/ca/ca-cert.pem")
now() { date +%s.%N; }
try() {  # try WHO: WHO writes a note to ImportBank's implicit collection
  use importbank "$1"
  echo "  $1: $(terms_submit --peerAddresses localhost:8051 --tlsRootCertFiles \
    "$ORGDIR/msp/tlscacerts/tlsca.pem" -- PutCreditNote LC-73 \
    "$(jq -cn '{note: ("checked" | @base64)}')" |
    sed 's/.*\(access denied: .*\]\) - .*/\1/')"
}
echo "== 1. Enroll trader8 at ImportBank's CA"
s=$(openssl rand -hex 16)
fabric-ca-client register "${CA[@]}" -M "$ORGDIR/ca-admin/msp" \
  -u https://localhost:8054 --id.name trader8 --id.secret "$s" --id.type client \
  >/dev/null 2>&1
fabric-ca-client enroll "${CA[@]}" -u "https://trader8:$s@localhost:8054" \
  -M "$ORGDIR/trader8/msp" >/dev/null 2>&1
cp "$ORGDIR/msp/config.yaml" "$ORGDIR/trader8/msp/"
try trader8
echo "== 2. Revoke at the CA: the clock starts"
t0=$(now)
fabric-ca-client revoke "${CA[@]}" -M "$ORGDIR/ca-admin/msp" -e trader8 \
  -r keycompromise --gencrl >/dev/null 2>&1
try trader8
echo "== 3. ImportBank updates its MSP in the channel: the clock stops at commit"
use importbank
peer channel fetch config "$W/config.pb" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" -c "$CHANNEL" >/dev/null 2>&1
configtxlator proto_decode --type common.Block --input "$W/config.pb" |
  jq '.data.data[0].payload.data.config' > "$W/config.json"
M='groups.ImportBankMSP.values.MSP.value.config.revocation_list'
jq --arg crl "$(base64 -w0 < "$ORGDIR/ca-admin/msp/crls/crl.pem")" \
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
h=$(peer channel getinfo -c "$CHANNEL" 2>/dev/null | grep -o '"height":[0-9]*')
peer channel update -f "$W/update.pb" -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" 2>&1 | grep -o 'Successfully submitted channel update' |
  sed 's/^/  /'
until [ "$(peer channel getinfo -c "$CHANNEL" 2>/dev/null |
  grep -o '"height":[0-9]*')" != "$h" ]; do sleep 0.2; done
printf '  revoked certificate accepted for %.1f s by this script\n' \
  "$(echo "$(now) - $t0" | bc)"
echo "== 4. The same calls again"
try trader8; try user1
