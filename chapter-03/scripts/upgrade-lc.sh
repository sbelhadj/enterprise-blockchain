#!/usr/bin/env bash
#
# Listing 3.23: upgrade to version 1.1 (sequence 2), then use the function it adds.
# Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
"$HERE/deploy-lc.sh" 1.1 2
source "$HERE/env.sh" org1
echo "== The LC issued under version 1.0 is still there, and 1.1 can show its history"
lc_query ReadLC LC-2026-001 | jq -c '{id, status}'
lc_query GetLCHistory LC-2026-001 | jq -c '.[] | {status, txId: .txId[0:12], timestamp}'
