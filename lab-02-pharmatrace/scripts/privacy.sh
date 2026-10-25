#!/usr/bin/env bash
#
# Listing L2.5: Part C milestones. The chaincode-level policy, the private price
# terms and the state-based endorsement of a custody transfer, each tested by a
# call that should fail and one that should succeed.
set -euo pipefail
source "$(dirname "$0")/env.sh"
B=B-2026-000 S='["P0001","P0002"]'
echo "== 1. Production needs the manufacturer's and the regulator's peers"
echo "manufacturer only:     $(ENDORSERS=manufacturer submit manufacturer \
  ProduceBatch $B 00012345600012 'Amoxicillin 500 mg capsules' "$S")"
echo "with the regulator:    $(ENDORSERS='manufacturer regulator' submit \
  manufacturer ProduceBatch $B 00012345600012 'Amoxicillin 500 mg capsules' "$S")"

echo "== 2. Price terms go to the two trading partners only"
echo "set terms:             $(ENDORSERS='manufacturer distributor' \
  TRANSIENT=$(terms '{"unitPrice":0.42,"currency":"EUR"}') \
  submit manufacturer SetTerms $B)"
echo "distributor reads:     $(query distributor ReadTerms $B)"
echo "pharmacy reads:"
query pharmacy ReadTerms $B | grep -o 'tx creator does not have read access[^"]*' |
  fold -s -w 76 | sed "s/^/  /" || true            # refused, as expected

echo "== 3. Custody moves only with the receiver's endorsement"
echo "ship to distributor:   $(ENDORSERS=manufacturer submit manufacturer \
  ShipBatch $B DistributorMSP)"
echo "receive, distributor:  $(ENDORSERS=distributor submit distributor \
  ReceiveBatch $B)"
echo "receive, both peers:   $(ENDORSERS='manufacturer distributor' submit \
  distributor ReceiveBatch $B)"
query regulator ReadBatch $B | jq -c '{id, status, holder}'
