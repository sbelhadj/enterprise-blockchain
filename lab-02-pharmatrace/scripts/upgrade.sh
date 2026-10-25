#!/usr/bin/env bash
#
# Listing L2.8: Part E upgrade. Version 1.1 adds an expiry date to a batch. The code
# changes, its tests must pass, and then every organization approves the new
# definition at sequence 2 before it is committed.
set -euo pipefail
source "$(dirname "$0")/env.sh"
REPO=$(cd "$LAB/.." && pwd) PATCH=lab-02-pharmatrace/upgrade/v1.1.patch
echo "== 1. Version 1.1 of the code, tested"
if git -C "$REPO" apply --check "$PATCH" 2>/dev/null; then
  git -C "$REPO" apply "$PATCH"
fi
(cd "$CC_PATH" && npm run build >/dev/null && npm test 2>&1 |
  grep -E 'passing|failing')
echo "== 2. Version 1.1 at sequence 2 in the network file, then the lifecycle"
jq '.chaincode.version = "1.1" | .chaincode.sequence = 2' "$NETFILE" \
  > "$NETFILE.new"
mv "$NETFILE.new" "$NETFILE"
"$NET/network.sh" "$NETFILE" generate | tail -1      # the new image tag
"$NET/network.sh" "$NETFILE" deploy
echo "== 3. Data written by version 1.0 is still there"
query pharmacy VerifySerial A0001 | jq -c '{verdict, batch, expiryDate}'
