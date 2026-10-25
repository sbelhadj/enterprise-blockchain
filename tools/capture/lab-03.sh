#!/usr/bin/env bash
#
# Captures the outputs printed in Lab 3, from a clean start, and the history page
# screenshot (Figure L3.2). Author's script, not a reader step. As in Labs 1 and 2,
# the peers run with LevelDB (STATEDB=goleveldb).
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/lab-03
LAB=$REPO/lab-03-parts-integration
S=$LAB/scripts
N="$REPO/network/network.sh $LAB/network.json"
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
source "$S/env.sh"
service_stop 2>/dev/null
$N down >/dev/null 2>&1
rm -rf "$LAB/service/wallet" "$LAB/service/.secrets" "$LAB/service/data"
( cd "$LAB/parts-chaincode" && npm run build >/dev/null )
( cd "$LAB/service" && npm run build >/dev/null )
run tests bash -c "cd $LAB/parts-chaincode && npm run --silent lint &&
  npm run --silent coverage | grep -E 'passing|failing|^(Statements|Branches)' &&
  cd $LAB/service && npm run --silent lint && npm run --silent coverage"
run up $N up
sleep 30                                   # gossip membership for discovery
run enroll "$S/enroll-users.sh"
service_start
run api "$S/api-demo.sh" ESN-1001
sleep 3
grep '^\[listener\]' "$LAB/service/data/service.log" | clean > "$OUT/listener.txt"
run restart "$S/restart-demo.sh" ESN-1001
run reconcile "$S/reconcile.sh" ESN-1001
run load "$S/load.sh" ESN-2001 5 10
run security "$S/security-check.sh"
NODE_PATH=$(npm root -g) node "$REPO/tools/capture/lab-03-ui.js" "$URL/" \
  "$(grep '^AMEL=' "$LAB/service/.secrets/api-keys.env" | cut -d= -f2)" ESN-1001 \
  "$REPO/figures/lab-03/Figure_L3_2.png"
service_stop
$N down >/dev/null 2>&1
rm -rf "$LAB/service/wallet" "$LAB/service/.secrets" "$LAB/service/data"
ls -l "$OUT"
