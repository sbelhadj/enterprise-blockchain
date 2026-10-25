#!/usr/bin/env bash
#
# Listing L2.6: Part D scenario. One batch from production to recall. Each call
# names the peers its policy needs: production, the manufacturer and regulator;
# a custody change, the holder (and the receiver to receive); a recall, the holder.
set -euo pipefail
source "$(dirname "$0")/env.sh"
B=B-2026-001 S='["A0001","A0002","A0003"]'
step() { printf '%-30s %s\n' "$1" "$2"; }
step "manufacturer produces" "$(ENDORSERS='manufacturer regulator' \
  submit manufacturer ProduceBatch $B 00012345600012 'Amoxicillin 500 mg capsules' \
  "$S")"
step "ships to distributor" "$(ENDORSERS=manufacturer \
  submit manufacturer ShipBatch $B DistributorMSP)"
step "distributor receives" "$(ENDORSERS='manufacturer distributor' \
  submit distributor ReceiveBatch $B)"
step "ships to pharmacy" "$(ENDORSERS=distributor \
  submit distributor ShipBatch $B PharmacyMSP)"
step "pharmacy receives" "$(ENDORSERS='distributor pharmacy' \
  submit pharmacy ReceiveBatch $B)"
step "pharmacy dispenses A0002" "$(ENDORSERS=pharmacy \
  submit pharmacy DispenseUnit $B A0002)"
for s in A0001 A0002 FAKE0001; do
  step "verify $s" "$(query pharmacy VerifySerial $s | jq -c '{verdict, batch}')"
done
step "pharmacy tries to recall" "$(ENDORSERS=pharmacy \
  submit pharmacy RecallBatch $B 'Out of stock')"
step "regulator recalls" "$(ENDORSERS=pharmacy submit regulator \
  RecallBatch $B 'Nitrosamine impurity above limit')"
step "verify A0001" "$(query pharmacy VerifySerial A0001 |
  jq -c '{verdict, batch}')"
echo "history of $B:"
query regulator GetHistory $B |
  jq -r '.[] | "  \(.status | .[0:9] | . + " " * (9 - length)) holder \(.holder),"
    + " written by \(.by)"'
