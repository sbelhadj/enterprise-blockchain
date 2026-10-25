#!/usr/bin/env bash
#
# Listing L1.12: four deliberate mistakes on the running network and the message
# each one produces. Each step undoes its change before the next.
set -uo pipefail
source "$(dirname "$0")/env.sh"
first() { grep -o -E "$1" | head -1; }

echo "== 1. TLS name mismatch: the client expects another host name"
use customs
CORE_PEER_TLS_SERVERHOSTOVERRIDE=peer0.customs.example.org \
  peer channel getinfo -c "$CHANNEL" 2>&1 |
  first 'x509: certificate is valid for [^"]*' | sed 's/ remoteaddress=.*//' |
  fold -s -w 80

echo "== 2. NodeOUs off for a client: its identity has no role"
use customs user1
mv "$ORGDIR/user1/msp/config.yaml" /tmp/lab1-config.yaml
query customs ReadShipment SH-0001 | first 'administrators must be declared.*'
mv /tmp/lab1-config.yaml "$ORGDIR/user1/msp/config.yaml"

echo "== 3. An organization without OrdererEndpoints under the V3_0 capability"
W=$(mktemp -d); cp -r "$BUILD/configtx.yaml" "$W/"
ln -s "$BUILD/organizations" "$W/organizations"
sed -i '0,/OrdererEndpoints/{/OrdererEndpoints/d}' "$W/configtx.yaml"
FABRIC_CFG_PATH=$W configtxgen -profile Channel -channelID test \
  -outputBlock "$W/test.block" 2>&1 |
  first 'orderer endpoints for organization .*' | fold -s -w 80
rm -rf "$W"

echo "== 4. The chaincode server is not running"
$COMPOSE stop "$CC-customs" 2>&1 | grep Error || true
P='could not launch chaincode [^:]*|grpc connection to [^:]*:[0-9]*'
P="$P|connection refused"
query customs ReadShipment SH-0001 | grep -o -E "$P" | awk '!seen[$0]++'
$COMPOSE start "$CC-customs" 2>&1 | grep Error || true
sleep 3
echo "after restart: $(query customs ReadShipment SH-0001 | jq -r .status)"
