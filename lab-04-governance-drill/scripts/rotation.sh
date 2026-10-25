#!/usr/bin/env bash
#
# Listing L4.3: Part C, certificate rotation while letters of credit keep flowing.
# CustomsAuthority renews its peer's TLS certificate and restarts the peer;
# ExportBank renews its administrator's certificate, revokes the old one and puts
# the revocation list into the channel.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ca() {  # ca KIND ARGS...: fabric-ca-client against $ORG's identity or TLS CA
  local kind=$1 port; shift
  port=$((BASE + 54)); [ "$kind" = tlsca ] && port=$((BASE + 55))
  FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client fabric-ca-client "$@" \
    -u "https://localhost:$port" --caname "$kind-$ORG" \
    --tls.certfiles "$ORGDIR/$kind/ca-cert.pem" 2>/dev/null
}
serial() { openssl x509 -in "$1" -noout -serial | cut -d= -f2 | cut -c1-16; }
traffic_start

echo "== 1. Renew peer0.customs's TLS certificate, then restart the peer"
org customs; T=$ORGDIR/peer0/tls D=$W/tls-renewal
rm -rf "$D"; mkdir -p "$D/msp/signcerts" "$D/msp/keystore"
cp "$T/server.crt" "$D/msp/signcerts/cert.pem"
cp "$T/server.key" "$D/msp/keystore/"
echo "  old: serial $(serial "$T/server.crt")..., valid until" \
  "$(openssl x509 -in "$T/server.crt" -noout -enddate | cut -d= -f2)"
ca tlsca reenroll -M "$D/msp" --enrollment.profile tls \
  --csr.hosts "peer0.$DOMAIN,localhost"
cp "$D/msp/signcerts/cert.pem" "$T/server.crt"
cp "$(ls -t "$D"/msp/keystore/* | head -1)" "$T/server.key"
echo "  new: serial $(serial "$T/server.crt")..., with a new key"
$COMPOSE stop peer0-customs 2>&1 | grep Error || true
$COMPOSE start peer0-customs 2>&1 | grep Error || true
wait_for 30 curl -sf "http://localhost:$((BASE + 443))/healthz"
use customs
echo "  peer0.customs back: $(peer channel getinfo -c "$CHANNEL" 2>&1 |
  grep -o '"height":[0-9]*')"

echo "== 2. Renew ExportBank's admin certificate"
org exportbank; A=$ORGDIR/admin/msp
rm -rf "$W/admin-old"; cp -r "$A" "$W/admin-old"          # kept for step 4 only
old=$(openssl x509 -in "$A/signcerts/cert.pem" -noout -serial | cut -d= -f2)
aki=$(openssl x509 -in "$A/signcerts/cert.pem" -noout -ext authorityKeyIdentifier |
  tail -1 | tr -d ' :' | tr 'A-F' 'a-f')
ca ca reenroll -M "$A"
echo "  old serial ${old:0:16}..., new serial $(serial "$A/signcerts/cert.pem")..."

echo "== 3. Revoke the old certificate and publish the CRL in the channel"
ca ca revoke -M "$ORGDIR/ca-admin/msp" -s "$(tr 'A-F' 'a-f' <<< "$old")" \
  -a "$aki" -r superseded --gencrl
fetch_config "$W/c.json"
M='.groups.ExportBankMSP.values.MSP.value.config.revocation_list'
jq --arg crl "$(base64 -w0 < "$ORGDIR/ca-admin/msp/crls/crl.pem")" \
  ".channel_group.groups.Application$M = [\$crl] |
   .channel_group.groups.Orderer$M = [\$crl]" "$W/c.json" > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/crl.pb"
sign_and_submit "$W/crl.pb" exportbank       # its own MSP: its own admin decides
sleep 3

echo "== 4. Old and new admin certificates"
use exportbank
for who in new old; do
  [ $who = old ] && export CORE_PEER_MSPCONFIGPATH=$W/admin-old
  printf '  %s, read the channel config: %s\n' "$who" "$(peer channel fetch config \
    /dev/null -o "$ORDERER" --tls --cafile "$ORDERER_CA" -c "$CHANNEL" 2>&1 |
    grep -o -E 'Received block: [0-9]+|FORBIDDEN' | head -1)"
  printf '  %s, list chaincode on its own peer: %s\n' "$who" \
    "$(peer lifecycle chaincode queryinstalled -O json 2>&1 |
    jq -r '.installed_chaincodes[0].label' 2>/dev/null || echo refused)"
done
traffic_stop
