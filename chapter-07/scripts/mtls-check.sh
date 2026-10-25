#!/usr/bin/env bash
#
# Listing 7.2: restart ImportBank's peer with client authentication required, then
# call it without and with a client certificate.
set -euo pipefail
source "$(dirname "$0")/env.sh"
MTLS="$COMPOSE -f $CH7/compose/compose-mtls.yaml"
$MTLS stop peer0-importbank >/dev/null 2>&1
$MTLS up -d peer0-importbank 2>&1 | grep -E 'Started|Error' || true
for i in $(seq 30); do
  curl -s localhost:8443/healthz | grep -q OK && break; sleep 1
done
sleep 5
use importbank admin
A=$ORGDIR/admin/tls
echo "== 1. Without a client certificate"
peer chaincode query -C "$CHANNEL" -n lcterms \
  -c "$(lc_args ReadCreditNote LC-2026-101)" 2>&1 | grep -o 'Error: .*' |
  sed 's/: failed to create new connection//' || true
echo "== 2. With the administrator's TLS client certificate"
CORE_PEER_TLS_CLIENTAUTHREQUIRED=true CORE_PEER_TLS_CLIENTCERT_FILE=$A/client.crt \
  CORE_PEER_TLS_CLIENTKEY_FILE=$A/client.key \
  peer chaincode query -C "$CHANNEL" -n lcterms \
  -c "$(lc_args ReadCreditNote LC-2026-101)" 2>&1 | grep -v InitCmdFactory
echo "peer log: $($MTLS logs peer0-importbank 2>&1 |
  grep -o "client didn't provide a certificate" | tail -1)"
echo "== 3. The other peers still reach it, with their own TLS certificates"
sleep 30
curl -s localhost:8443/metrics |
  grep '^gossip_membership_total_peers_known{channel="lcchannel"}'
