#!/usr/bin/env bash
#
# Listing L1.10: adds an organization to the channel's Application group by
# configuration update. The Admins policy is MAJORITY Admins, so the founders sign
# in turn until a majority has signed; the last signer submits. Then the new
# organization starts its nodes, joins its peer and approves the chaincode
# definition already in force.
# Usage: add-org.sh ORG, for an organization marked "joins": "later"
set -euo pipefail
source "$(dirname "$0")/common.sh"
NEW=$1; org "$NEW"
if [ "$ORDERER_NODE" = true ]; then
  echo "add-org adds peer organizations only" >&2; exit 1
fi
NEW_MSP=$MSP W=$BUILD/channel-artifacts/add-$NEW
rm -rf "$W"; mkdir -p "$W"
"$NET/lib/ca.sh" "$NEW" >/dev/null && "$NET/lib/enroll.sh" "$NEW" >/dev/null
"$NET/lib/nodes.sh" "$NEW"

echo "== $NEW_MSP's definition, without orderer endpoints, with its anchor peer"
ANCHOR="{mod_policy: \"Admins\", version: \"0\", value: {anchor_peers:
  [{host: \"peer0.$DOMAIN\", port: $((BASE + 51))}]}}"
FABRIC_CFG_PATH=$BUILD configtxgen -printOrg "$NEW_MSP" 2>/dev/null |
  jq "del(.values.Endpoints) | .values.AnchorPeers = $ANCHOR" > "$W/org.json"
jq -r '.values.MSP.value.config.name + " policies: " +
  (.policies | keys | join(" "))' "$W/org.json"

FIRST=${FOUNDERS%% *}; use "$FIRST"
peer channel fetch config "$W/config.pb" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" \
  -c "$CHANNEL" >/dev/null 2>&1
configtxlator proto_decode --type common.Block --input "$W/config.pb" |
  jq '.data.data[0].payload.data.config' > "$W/config.json"
jq --slurpfile org "$W/org.json" --arg m "$NEW_MSP" \
  '.channel_group.groups.Application.groups[$m] = $org[0]' "$W/config.json" \
  > "$W/modified.json"
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

members=$(jq '.channel_group.groups.Application.groups | length' "$W/config.json")
need=$((members / 2 + 1)) n=0
echo "== $members application organizations: $need signatures needed"
for o in $FOUNDERS; do
  use "$o"; n=$((n + 1))
  if [ $n -lt $need ]; then
    peer channel signconfigtx -f "$W/update.pb" >/dev/null 2>&1
    echo "$MSP signs"
  else
    echo "$MSP signs and submits: $(peer channel update -f "$W/update.pb" \
      -c "$CHANNEL" -o "$ORDERER" --tls --cafile "$ORDERER_CA" 2>&1 |
      grep -o 'Successfully submitted channel update' || echo FAILED)"
    break
  fi
done

echo "== $NEW_MSP joins its peer and approves the chaincode definition"
use "$FIRST"
SEQ=$(peer lifecycle chaincode querycommitted -C "$CHANNEL" -n "$CC" -O json |
  jq .sequence)
use "$NEW"
wait_for 20 peer channel fetch 0 "$W/genesis.block" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" -c "$CHANNEL"
peer channel join -b "$W/genesis.block" 2>&1 | grep -o 'Successfully submitted.*'
NO_COMMIT=1 SEQUENCE=$SEQ "$NET/lib/deploy.sh" "$NEW"
