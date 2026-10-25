#!/usr/bin/env bash
#
# Listing 6.2: let Fabric check a design before any chaincode exists. Run it on the
# Chapter 5 network (chapter-05/network.sh up). The collections are approved for a
# chaincode named freight that is never installed or committed.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../chapter-05/scripts/env.sh"
approve() {  # approve FILE: ExportBank approves freight 1.0 with these collections
  peer lifecycle chaincode approveformyorg -o "$ORDERER" --tls \
    --cafile "$ORDERER_CA" -C "$CHANNEL" -n freight -v 1.0 --sequence 1 \
    --collections-config "$1" 2>&1 |
    grep -o -E "committed with status \([A-Z_]+\)|collection-name: .*"
}
use exportbank

echo "== 1. The design as written, on a channel without its organizations"
approve "$HERE/collections-freight.json" || true

echo "== 2. The same design with Chapter 5's organizations in the three roles"
MAPPED=$CH5/channel-artifacts/collections-mapped.json
sed -e 's/RetailerMSP/ImportBankMSP/g' -e 's/CarrierAMSP/ExportBankMSP/g' \
  -e 's/CarrierBMSP/CustomsMSP/g' "$HERE/collections-freight.json" > "$MAPPED"
approve "$MAPPED"

echo "== 3. What the peer recorded for ExportBank's approval"
peer lifecycle chaincode queryapproved -C "$CHANNEL" -n freight --sequence 1 \
  -O json | jq -c '
  def msps: [(.Payload.SignaturePolicy // .Type.SignaturePolicy).identities[]
             | .principal | @base64d | gsub("[^A-Za-z]"; "")];
  .collections.config[].Payload.StaticCollectionConfig |
  {name, members: (.member_orgs_policy | msps),
   endorsers: (.endorsement_policy | msps), required_peer_count}'
