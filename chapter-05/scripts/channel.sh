#!/usr/bin/env bash
#
# Listing 5.8: create lcchannel. Each organization's administrator joins its own
# orderer through the channel participation API, then its own peer. Nobody can do it
# for another organization: an orderer accepts admin calls only from client
# certificates issued by its own TLS CA.
set -euo pipefail
source "$(dirname "$0")/env.sh"
BLOCK=$CH5/channel-artifacts/$CHANNEL.block
mkdir -p "$CH5/channel-artifacts"
FABRIC_CFG_PATH=$CH5/config configtxgen -profile LCChannel -channelID "$CHANNEL" \
  -outputBlock "$BLOCK" 2>&1 | grep -E 'orderer type|Writing genesis' |
  sed 's/.*-> //'

for o in exportbank importbank customs; do
  org $o; A=$ORGDIR/admin/tls
  echo "== $MSP joins orderer0.$DOMAIN"
  osnadmin channel join --channelID "$CHANNEL" --config-block "$BLOCK" \
    -o "localhost:$((BASE + 53))" --ca-file "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    --client-cert "$A/client.crt" --client-key "$A/client.key" |
    grep -E 'Status|"consensusRelation"|"status"'
done

for o in exportbank importbank; do   # CustomsAuthority's peer joins in Section 5.9
  use $o
  echo "== $MSP joins peer0.$DOMAIN"
  peer channel join -b "$BLOCK" 2>&1 | grep -o 'Successfully submitted.*'
done

sleep 3                                # one Raft election timeout
use exportbank; A=$ORGDIR/admin/tls
osnadmin channel list --channelID "$CHANNEL" -o "localhost:$((BASE + 53))" \
  --ca-file "$ORGDIR/msp/tlscacerts/tlsca.pem" --client-cert "$A/client.crt" \
  --client-key "$A/client.key" | grep -E '"(name|status|consensusRelation|height)"'
