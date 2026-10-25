#!/usr/bin/env bash
#
# Appendix A, Exercises 3.1, 3.2 and 3.5 on the network: version 1.2 against LCs
# issued under 1.0 and 1.1, then the new functions. Run from
# fabric-samples/test-network after deploy-1.2.sh.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ENV=$HERE/../../chapter-03/scripts/env.sh
DOCS=$HERE/../../chapter-03/sample-documents/bill-of-lading.txt
EXPIRY=$(date -u -d '+180 days' +%F)
as() { source "$ENV" "$@"; }
# submit: one line, the commit status or the chaincode's own message
submit() {
  lc_submit "$@" 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|message:"[^"]*"' | head -1 |
    sed -e 's/committed with status/committed/' -e 's/message:"\(.*\)"/\1/'
}
issue() {  # issue ID BENEFICIARY AMOUNT, as ImportBank's LC officer
  as org2 lcofficer
  echo "  IssueLC $1 for $2: $(submit IssueLC "$1" 'Tunis Olive Imports' "$2" \
    Org1MSP "$3" EUR "$EXPIRY" 'olive oil')"
}

echo "== 3.5: LCs issued under 1.0 and 1.1, read with 1.2"
as org1
for id in LC-V10 LC-V11; do
  lc_query ReadLC $id 2>/dev/null | jq -c '{id, status, amount, rejectionReason}'
done
echo "== 3.5: LC-V10, issued under 1.0, is paid under 1.2"
echo "  AcceptLC: $(submit AcceptLC LC-V10)"
echo "  PresentDocuments: $(submit PresentDocuments LC-V10 \
  "$(sha256sum "$DOCS" | cut -d' ' -f1)")"
as org2; echo "  PayLC: $(submit PayLC LC-V10)"
lc_query ReadLC LC-V10 2>/dev/null | jq -c '{id, status}'

echo "== 3.1: AmendLC and RejectLC"
try() {  # try LABEL FUNCTION ARG...: the label, then the outcome on its own line
  echo "  $1"; shift; echo "    $(submit "$@")"
}
as org1; try 'ExportBank amends LC-V11' AmendLC LC-V11 1 ''
as org2; try 'ImportBank amends LC-V11' AmendLC LC-V11 130000000 ''
lc_query ReadLC LC-V11 2>/dev/null | jq -c '{id, status, amount, expiryDate}'
try 'ImportBank rejects LC-V11' RejectLC LC-V11 'no'
as org1; try 'ExportBank rejects LC-V11' RejectLC LC-V11 'goods not eligible'
lc_query ReadLC LC-V11 2>/dev/null | jq -c '{id, status, rejectionReason}'
try 'ExportBank rejects it again' RejectLC LC-V11 'twice'

echo "== 3.2: five LCs for one beneficiary, two for another"
for n in 1 2 3 4 5; do issue "LC-B$n" 'Sfax Olive Oil Co' "${n}0000000"; done
for n in 6 7; do issue "LC-B$n" 'Nabeul Ceramics' "${n}0000000"; done
as org1
BOOKMARK="" page=0
while :; do
  page=$((page + 1))
  R=$(lc_query GetLCsByBeneficiary 'Sfax Olive Oil Co' 2 "$BOOKMARK" 2>/dev/null)
  echo "  page $page: $(jq -c '[.records[].id]' <<< "$R"), bookmark" \
    "$(jq -r '.bookmark | if . == "" then "(none)" else .[0:24] + "..." end' \
    <<< "$R")"
  BOOKMARK=$(jq -r .bookmark <<< "$R")
  [ -z "$BOOKMARK" ] && break
done
echo "  Nabeul Ceramics: $(lc_query GetLCsByBeneficiary 'Nabeul Ceramics' 10 '' \
  2>/dev/null | jq -c '[.records[].id]')"
