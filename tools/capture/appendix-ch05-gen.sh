#!/usr/bin/env bash
#
# Captures the Appendix A outputs for Exercises 5.2 and 5.5 on a network built
# with the Lab 1 generator, through the Exercise 5.5 wrapper. Author's script.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/appendix D=$REPO/solutions/chapter-05/ex5-2
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
"$REPO/network/network.sh" "$D/network.json" down >/dev/null 2>&1
rm -rf "$D/logs"
( cd "$REPO/chapter-03/lc-chaincode" && npm run build >/dev/null )
{ "$D/network.sh" up; "$D/network.sh" up; "$D/network.sh" addOrg shippingline
  sleep 20                                 # gossip: the new peer becomes known
  "$D/network.sh" status; } 2>&1 | clean > "$OUT/ex5-5-console.txt"
grep -A12 '== .* application organizations' "$D/logs/network.log" | clean \
  > "$OUT/ex5-2-add-org.txt"
"$D/policy.sh" 2>&1 | clean > "$OUT/ex5-2-policy.txt"
"$D/network.sh" down 2>&1 | clean >> "$OUT/ex5-5-console.txt"
cp "$D/logs/network.log" "$OUT/ex5-5-network.log"; sed -i "s#$(dirname "$REPO")#~#g" "$OUT/ex5-5-network.log"
cat "$OUT/ex5-5-console.txt" "$OUT/ex5-2-add-org.txt" "$OUT/ex5-2-policy.txt"
