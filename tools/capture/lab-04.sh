#!/usr/bin/env bash
#
# Captures the outputs printed in Lab 4 from a clean start: the network comes up,
# then the five parts of the drill run in order on the same network. Author's
# script, not a reader step. As in Labs 1 to 3, the peers run with LevelDB
# (STATEDB=goleveldb); Part E deletes node data with the process runner's
# volume-rm, which stands in for docker volume rm.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/lab-04
LAB=$REPO/lab-04-governance-drill
B=$LAB/build
export VOLRM="$DC --env-file $B/.secrets/network.env -f $B/compose-ca.yaml -f $B/compose-net.yaml volume-rm"
N="$REPO/network/network.sh $LAB/network.json"
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
$N down >/dev/null 2>&1
( cd "$REPO/chapter-03/lc-chaincode" && npm run build >/dev/null )
run up $N up
sleep 30                                   # gossip membership for discovery
run policies "$LAB/scripts/policies.sh"
run vote "$LAB/scripts/vote.sh"
run rotation "$LAB/scripts/rotation.sh"
run ordering "$LAB/scripts/ordering.sh"
run recovery "$LAB/scripts/recovery.sh"
$N down >/dev/null 2>&1
ls -l "$OUT"
