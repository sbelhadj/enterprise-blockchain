#!/usr/bin/env bash
#
# Listing L2.10: Part E milestone. The listener runs while a new batch gets an
# expiry date and is then recalled by its manufacturer.
set -euo pipefail
source "$(dirname "$0")/env.sh"
B=B-2026-002 OUT=$(mktemp)
(cd "$LAB/listener" && node dist/recall-alerts.js 1 > "$OUT" 2>&1) &
sleep 3
step() { printf '%-32s %s\n' "$1" "$2"; }
step "manufacturer produces $B" "$(ENDORSERS='manufacturer regulator' \
  submit manufacturer ProduceBatch $B 00012345600012 'Amoxicillin 500 mg capsules' \
  '["C0001","C0002"]')"
step "sets expiry 2028-03-31" "$(ENDORSERS=manufacturer \
  submit manufacturer SetExpiry $B 2028-03-31)"
step "verify C0001" "$(query pharmacy VerifySerial C0001 |
  jq -c '{verdict, expiryDate}')"
step "manufacturer recalls $B" "$(ENDORSERS=manufacturer submit manufacturer \
  RecallBatch $B 'Label misprint: wrong strength on outer carton')"
wait
echo "== listener output"
cat "$OUT"; rm -f "$OUT"
