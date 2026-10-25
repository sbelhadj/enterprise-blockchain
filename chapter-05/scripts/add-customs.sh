#!/usr/bin/env bash
#
# Listing 5.14: add CustomsAuthority to the application side of lcchannel with a
# configuration update. The Application Admins policy is MAJORITY Admins, so with
# two banks both must sign. Step 3 shows the update refused with one signature.
set -euo pipefail
source "$(dirname "$0")/env.sh"
W=$CH5/channel-artifacts/add-customs
rm -rf "$W"; mkdir -p "$W"; cd "$W"
quiet() { grep -v -E 'InitCmdFactory|Received block|Retrieving' || true; }
encode() { configtxlator proto_encode --type "$1" --input "$2" --output "$3"; }
decode() { configtxlator proto_decode --type "$1" --input "$2"; }

echo "== 1. ExportBank fetches and decodes the current configuration"
use exportbank
peer channel fetch config config.pb -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -c "$CHANNEL" 2>&1 | quiet
decode common.Block config.pb | jq '.data.data[0].payload.data.config' > config.json
jq -c '.channel_group.groups.Application.groups | keys' config.json

echo "== 2. Add CustomsMSP to the Application group and compute the difference"
ANCHOR='{mod_policy: "Admins", version: "0",
  value: {anchor_peers: [{host: "peer0.customs.example.com", port: 9051}]}}'
FABRIC_CFG_PATH=$CH5/config configtxgen -printOrg CustomsMSP 2>/dev/null |
  jq "del(.values.Endpoints) | .values.AnchorPeers = $ANCHOR" > customs.json
jq --slurpfile org customs.json \
  '.channel_group.groups.Application.groups.CustomsMSP = $org[0]' config.json \
  > modified.json
encode common.Config config.json config.pbc
encode common.Config modified.json modified.pbc
configtxlator compute_update --channel_id "$CHANNEL" --original config.pbc \
  --updated modified.pbc --output update.pb
decode common.ConfigUpdate update.pb | jq -c '{
  read: (.read_set.groups.Application.groups | keys),
  write: (.write_set.groups.Application.groups | keys)}'
decode common.ConfigUpdate update.pb | jq --arg ch "$CHANNEL" '{payload: {
  header: {channel_header: {channel_id: $ch, type: 2}},
  data: {config_update: .}}}' > envelope.json
encode common.Envelope envelope.json update_envelope.pb

echo "== 3. ExportBank alone submits it"
cp update_envelope.pb one_signature.pb
peer channel update -f one_signature.pb -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" 2>&1 | grep -o 'Error: .*' | sed 's/.*: //' |
  fold -s -w 80 || true

echo "== 4. ExportBank signs, ImportBank signs and submits"
peer channel signconfigtx -f update_envelope.pb 2>&1 | quiet
use importbank
peer channel update -f update_envelope.pb -c "$CHANNEL" -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" 2>&1 | grep -o 'Successfully submitted channel update'

echo "== 5. CustomsAuthority joins its peer and approves the chaincode definition"
use customs
sleep 3
peer channel fetch 0 "$CHANNEL.block" -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -c "$CHANNEL" 2>&1 | quiet
peer channel join -b "$CHANNEL.block" 2>&1 | grep -o 'Successfully submitted.*'
NO_COMMIT=1 "$CH5/scripts/deploy-cc.sh" customs
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n lc | tail -1

echo "== 6. A customs officer reads the letter of credit"
use customs user1
sleep 3
lc_query ReadLC LC-2026-101 | jq -c '{id, status, issuingBank, advisingBank}'
