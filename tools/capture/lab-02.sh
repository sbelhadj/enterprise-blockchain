#!/usr/bin/env bash
#
# Captures the outputs printed in Lab 2, from a clean start, then puts the
# chaincode and the network file back at version 1.0. Author's script, not a reader
# step. As in Lab 1, the peers run with LevelDB (STATEDB=goleveldb).
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/lab-02
LAB=$REPO/lab-02-pharmatrace
N="$REPO/network/network.sh $LAB/network.json"
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
cp "$LAB/network.json" /tmp/lab2-network.json
$N down >/dev/null 2>&1
( cd "$LAB/pharmatrace-chaincode" && npm run build >/dev/null )
( cd "$LAB/listener" && npm run build >/dev/null )
run tests bash -c "cd $LAB/pharmatrace-chaincode && npm run lint && npm run coverage"
run up $N up
sleep 30                                   # gossip membership: discovery, private data
run privacy "$LAB/scripts/privacy.sh"
run scenario "$LAB/scripts/scenario.sh"
run upgrade "$LAB/scripts/upgrade.sh"
sleep 5
run recall-alert "$LAB/scripts/recall-alert.sh"
$N down >/dev/null 2>&1
git -C "$REPO" apply -R lab-02-pharmatrace/upgrade/v1.1.patch
cp /tmp/lab2-network.json "$LAB/network.json"
( cd "$LAB/pharmatrace-chaincode" && npm run build >/dev/null )
ls -l "$OUT"
