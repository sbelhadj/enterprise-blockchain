#!/usr/bin/env bash
#
# Listing 3.10: issue three more LCs, then page through ImportBank's LCs two at a time.
# Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
EXPIRY=$(date -u -d '+180 days' +%F)
source "$HERE/env.sh" org2 lcofficer
for n in 3 4 5; do
  lc_submit IssueLC "LC-2026-00$n" 'Tunis Olive Imports' 'Sfax Olive Oil Co' Org1MSP \
    "${n}0000000" EUR "$EXPIRY" 'olive oil' 2>&1 |
    grep -o 'committed with status ([A-Z_]*)' | head -1
done

BOOKMARK=""
for page in 1 2 3; do
  RESULT=$(lc_query GetLCsByIssuingBank Org2MSP 2 "$BOOKMARK")
  SUMMARY=$(jq -c '{ids: [.records[].id], fetchedRecordsCount, bookmark}' <<< "$RESULT")
  echo "page $page: $SUMMARY"
  BOOKMARK=$(jq -r .bookmark <<< "$RESULT")
  [ -z "$BOOKMARK" ] && break
done
