#!/usr/bin/env bash
#
# Listing 8.1: change how the orderers cut blocks.
#   batch.sh TIMEOUT MAX_MESSAGES     for example: batch.sh 250ms 100
# BatchTimeout and BatchSize live in the channel's Orderer group, whose Admins
# policy is MAJORITY Admins of the three orderer organizations: ExportBank signs,
# ImportBank signs and submits.
set -euo pipefail
source "$(dirname "$0")/../../chapter-05/scripts/env.sh"
TIMEOUT=${1:?timeout, such as 2s or 250ms} COUNT=${2:?maximum messages per block}
W=$CH5/channel-artifacts/batch; rm -rf "$W"; mkdir -p "$W"

use exportbank
peer channel fetch config "$W/config.pb" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" -c "$CHANNEL" >/dev/null 2>&1
configtxlator proto_decode --type common.Block --input "$W/config.pb" |
  jq '.data.data[0].payload.data.config' > "$W/config.json"
O=.channel_group.groups.Orderer.values
jq "$O.BatchTimeout.value.timeout = \"$TIMEOUT\" |
    $O.BatchSize.value.max_message_count = $COUNT" "$W/config.json" \
  > "$W/modified.json"
jq -c "{before: {timeout: $O.BatchTimeout.value.timeout,
  max_message_count: $O.BatchSize.value.max_message_count,
  preferred_max_bytes: $O.BatchSize.value.preferred_max_bytes}}" "$W/config.json"
if cmp -s <(jq -S . "$W/config.json") <(jq -S . "$W/modified.json"); then
  echo "already set; no update needed"; exit 0     # compute_update would refuse
fi

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

peer channel signconfigtx -f "$W/update.pb" >/dev/null 2>&1   # ExportBank
use importbank
peer channel update -f "$W/update.pb" -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" 2>&1 | grep -o 'Successfully submitted channel update'
sleep 3
peer channel fetch config "$W/after.pb" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" -c "$CHANNEL" >/dev/null 2>&1
configtxlator proto_decode --type common.Block --input "$W/after.pb" |
  jq -c ".data.data[0].payload.data.config | {after: {
    timeout: $O.BatchTimeout.value.timeout,
    max_message_count: $O.BatchSize.value.max_message_count,
    preferred_max_bytes: $O.BatchSize.value.preferred_max_bytes}}"
