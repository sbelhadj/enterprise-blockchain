#!/usr/bin/env bash
#
# Listing 5.11: the Chapter 3 contract on the new network. ImportBank's LC officer
# issues a letter of credit, ExportBank accepts it, and both banks read it.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ID=${1:-LC-2026-101}

use importbank lcofficer
echo "== ImportBank's LC officer issues $ID: $(lc_submit IssueLC "$ID" \
  'Tunis Olive Imports' 'Sfax Olive Oil Co' ExportBankMSP 12500000 USD 2027-06-30 \
  'Extra virgin olive oil, 20 t')"
use exportbank user1
echo "== ExportBank accepts it: $(lc_submit AcceptLC "$ID")"
for o in exportbank importbank; do
  use $o user1
  echo "== read by $MSP on peer0.$DOMAIN"
  lc_query ReadLC "$ID" |
    jq -c '{id, status, issuingBank, advisingBank, amount, currency}'
done
