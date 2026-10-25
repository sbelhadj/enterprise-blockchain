#!/usr/bin/env bash
#
# Listing L1.11: Part E milestone. With four application organizations, MAJORITY
# Endorsement needs three. FreightForwarder books a pickup endorsed by three
# organizations including itself; the same call endorsed by two is invalidated.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ID=${1:-SH-0001}
use shippingline
echo "application orgs: $(peer channel fetch config /dev/stdout \
  -c "$CHANNEL" -o "$ORDERER" --tls --cafile "$ORDERER_CA" 2>/dev/null |
  configtxlator proto_decode --type common.Block |
  jq -r '.data.data[0].payload.data.config.channel_group.groups.Application.groups |
    keys | join(" ")')"
echo "two endorsers (customs, forwarder):" \
  "$(ENDORSERS='customs forwarder' submit forwarder RecordEvent "$ID" BOOK_PICKUP)"
echo "three endorsers (shippingline, customs, forwarder):" \
  "$(ENDORSERS='shippingline customs forwarder' submit forwarder RecordEvent \
    "$ID" BOOK_PICKUP)"
echo "PortTerminal GATE_OUT: $(ENDORSERS='portterminal customs forwarder' \
  submit portterminal RecordEvent "$ID" GATE_OUT)"
query forwarder GetHistory "$ID" | jq -r '.[] | "  \(.status) by \(.by)"'
heights
