#!/usr/bin/env bash
#
# Listing L1.6: creates the channel: each founding organization's administrator
# joins its own orderer with osnadmin, then its own peer.
set -euo pipefail
source "$(dirname "$0")/common.sh"
BLOCK=$BUILD/channel-artifacts/$CHANNEL.block
mkdir -p "$BUILD/channel-artifacts"
FABRIC_CFG_PATH=$BUILD configtxgen -profile Channel -channelID "$CHANNEL" \
  -outputBlock "$BLOCK" 2>&1 | grep -E 'orderer type' | sed 's/.*-> //'
osn() {  # osn ARGS...: osnadmin against this organization's orderer, as its admin
  osnadmin channel "$@" -o "localhost:$((BASE + 53))" \
    --ca-file "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    --client-cert "$ORGDIR/admin/tls/client.crt" \
    --client-key "$ORGDIR/admin/tls/client.key"
}
for o in $FOUNDERS; do
  org "$o"; [ "$ORDERER_NODE" = true ] || continue
  printf '%-36s %s\n' "orderer0.$DOMAIN joins $CHANNEL:" \
    "$(osn join --channelID "$CHANNEL" --config-block "$BLOCK" |
       grep -o 'Status: [0-9]*')"
done
for o in $FOUNDERS; do
  use "$o"
  wait_for 20 peer channel join -b "$BLOCK"
  printf '%-36s %s\n' "peer0.$DOMAIN joins $CHANNEL:" \
    "$(peer channel getinfo -c "$CHANNEL" 2>/dev/null | grep -o '"height":[0-9]*')"
done
