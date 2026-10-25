#!/usr/bin/env bash
#
# Listing 3.15: three calls the chaincode refuses during endorsement.
# Run from fabric-samples/test-network.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
EXPIRY=$(date -u -d '+180 days' +%F)
ARGS=(LC-2026-002 'Tunis Olive Imports' 'Sfax Olive Oil Co' Org1MSP 40000000 EUR
      "$EXPIRY" '5 t dates')
reason() { grep -o 'message:"[^"]*"' | head -1; }

echo "== 1. ImportBank's administrator has no lc.role attribute"
source "$HERE/env.sh" org2 Admin
lc_submit IssueLC "${ARGS[@]}" 2>&1 | reason

echo "== 2. The LC officer issues LC-2026-002; ImportBank then tries to accept its own LC"
source "$HERE/env.sh" org2 lcofficer
lc_submit IssueLC "${ARGS[@]}" 2>&1 | grep -o 'committed with status ([A-Z_]*)' | head -1
source "$HERE/env.sh" org2 Admin
lc_submit AcceptLC LC-2026-002 2>&1 | reason

echo "== 3. ExportBank presents documents before accepting"
source "$HERE/env.sh" org1
HASH=$(printf x | sha256sum | cut -d' ' -f1)
lc_submit PresentDocuments LC-2026-002 "$HASH" 2>&1 | reason
