#!/usr/bin/env bash
#
# Captures what Fabric 3.1 does with a Solo or Kafka profile (Chapter 4, Common Mistakes).
# Author's script, not a reader step. Runs on the four-orderer test network, as local processes.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/chapter-04
TN=$SAMPLES/test-network
W=$REPO/work/chapter-04/legacy
mkdir -p "$OUT" "$W"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error PATH=$SAMPLES/bin:$PATH
NODE_CTL=$REPO/tools/native/testnet-native.sh
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" -e "s#$(dirname "$REPO")#~#g"; }

cd "$TN"
"$NODE_CTL" down
"$NODE_CTL" up -bft || exit 1
ORD=$TN/organizations/ordererOrganizations/example.com
ADMIN=$ORD/users/Admin@example.com/tls
{
  for type in kafka solo; do
    echo "== OrdererType: $type"
    sed "s#\.\./organizations#$TN/organizations#g" bft-config/configtx.yaml > "$W/configtx.yaml"
    sed -e "s#ORDERERS#$ORD/orderers#g" -e "s/OrdererType: etcdraft/OrdererType: $type/" \
      -e "s/ChannelUsingRaft3/ChannelUsingLegacy/" \
      "$REPO/chapter-04/config/raft3-profile.yaml" >> "$W/configtx.yaml"
    FABRIC_CFG_PATH=$W configtxgen -profile ChannelUsingLegacy -channelID legacy$type \
      -outputBlock "$W/$type.block" 2>&1 | grep -E 'PANI|Writing genesis' | head -2
    [ -s "$W/$type.block" ] || continue
    osnadmin channel join --channelID legacy$type --config-block "$W/$type.block" \
      -o localhost:7053 --ca-file "$ORD/orderers/orderer.example.com/tls/ca.crt" \
      --client-cert "$ADMIN/client.crt" --client-key "$ADMIN/client.key" 2>&1
  done
} 2>&1 | clean > "$OUT/legacy-orderer-types.txt"
"$NODE_CTL" down
cat "$OUT/legacy-orderer-types.txt"
