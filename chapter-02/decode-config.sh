#!/usr/bin/env bash
#
# Listing 2.2: fetch the latest configuration block of mychannel and read it.
# Run from fabric-samples/test-network.
set -euo pipefail
source "$(dirname "$0")/../chapter-01/org1-env.sh"
# Scratch files go to work/ in the companion repository (ignored by Git), not into fabric-samples
WORK=$(cd "$(dirname "$0")/.." && pwd)/work; mkdir -p "$WORK"
ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

peer channel fetch config "$WORK/config_block.pb" -c mychannel -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA"
configtxlator proto_decode --type common.Block --input "$WORK/config_block.pb" |
  jq '.data.data[0].payload.data.config' > "$WORK/config.json"
echo "config saved to work/config.json in the companion repository"

echo "== Member organizations of the application side"
jq -r '.channel_group.groups.Application.groups | keys[]' "$WORK/config.json"
echo "== Capabilities: channel, orderer, application"
jq -c '[.channel_group.values.Capabilities.value.capabilities,
        .channel_group.groups.Orderer.values.Capabilities.value.capabilities,
        .channel_group.groups.Application.values.Capabilities.value.capabilities]' "$WORK/config.json"
echo "== Application policies"
jq -c '.channel_group.groups.Application.policies | to_entries[] |
       {(.key): "\(.value.policy.value.rule) \(.value.policy.value.sub_policy)"}' "$WORK/config.json"
echo "== Ordering: type, consenters and batching"
jq -c '.channel_group.groups.Orderer.values.ConsensusType.value.type,
       [.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[] |
        "\(.host):\(.port)"],
       .channel_group.groups.Orderer.values.BatchTimeout.value,
       .channel_group.groups.Orderer.values.BatchSize.value' "$WORK/config.json"
echo "== Anchor peers"
jq -c '.channel_group.groups.Application.groups[] |
       .values.AnchorPeers.value.anchor_peers' "$WORK/config.json"
echo "== Where peers find the orderers"
jq -c '.channel_group.values.OrdererAddresses.value.addresses,
       .channel_group.groups.Orderer.groups.OrdererOrg.values.Endpoints.value.addresses' "$WORK/config.json"
