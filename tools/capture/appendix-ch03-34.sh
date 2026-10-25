#!/usr/bin/env bash
#
# Captures the Appendix A output for Exercise 3.4 on a network built with the
# Lab 1 generator: two banks, then CustomsAuthority added with add-org, which
# does what test-network's addOrg3 scripts do. Author's script, not a reader step.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/appendix
D=$REPO/solutions/chapter-03/ex3-4
N="$REPO/network/network.sh $D/network.json"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
$N down >/dev/null 2>&1
( cd "$REPO/chapter-03/lc-chaincode" && npm run build >/dev/null )
$N up > /dev/null 2>&1 || { echo "up failed"; exit 1; }
$N add-org customs 2>&1 | clean > "$OUT/ex3-4-add-org.txt"
sleep 20                                   # gossip: the new peer becomes known
"$D/per-asset.sh" 2>&1 | clean > "$OUT/ex3-4-per-asset.txt"
$N down >/dev/null 2>&1; rm -rf "$D/build"
cat "$OUT/ex3-4-add-org.txt" "$OUT/ex3-4-per-asset.txt"
