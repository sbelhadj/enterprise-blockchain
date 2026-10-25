#!/usr/bin/env bash
#
# Listing L1.8: Part D smoke test. Each organization records the event it is
# responsible for, every organization reads the result, and one organization tries
# an event that is not its own.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ID=${1:-SH-0001}
echo "ShippingLine  CreateShipment $ID: $(submit shippingline CreateShipment "$ID" \
  MSCU1234565 'MSC Aurora' CNSHA 'Carthage Foods')"
echo "ShippingLine  ARRIVE:    $(submit shippingline RecordEvent "$ID" ARRIVE)"
echo "PortTerminal  DISCHARGE: $(submit portterminal RecordEvent "$ID" DISCHARGE)"
echo "Customs       RELEASE:   $(submit customs RecordEvent "$ID" RELEASE)"
echo "PortTerminal  RELEASE:   $(submit portterminal RecordEvent "$ID" RELEASE)"
for o in $FOUNDERS; do
  printf '%-13s reads: %s\n' "$o" \
    "$(query "$o" ReadShipment "$ID" | jq -c '{status, updatedBy}')"
done
heights
