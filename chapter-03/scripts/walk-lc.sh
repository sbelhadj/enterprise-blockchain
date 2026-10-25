#!/usr/bin/env bash
#
# Listing 3.21: take LC-2026-001 from ISSUED to PAID. Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DOCS=$HERE/../sample-documents/bill-of-lading.txt

echo "== ExportBank accepts the LC"
source "$HERE/env.sh" org1
lc_submit AcceptLC LC-2026-001 2>&1 | grep -E 'committed with status' | head -1

echo "== ExportBank presents the documents; only their SHA-256 goes on the ledger"
HASH=$(sha256sum "$DOCS" | cut -d' ' -f1)
lc_submit PresentDocuments LC-2026-001 "$HASH" 2>&1 |
  grep -E 'committed with status' | head -1

echo "== ImportBank pays"
source "$HERE/env.sh" org2
lc_submit PayLC LC-2026-001 2>&1 | grep -E 'committed with status' | head -1

lc_query ReadLC LC-2026-001 | jq '{id, status, documentsHash, issuedAt, updatedAt}'
