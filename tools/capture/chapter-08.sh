#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 8 on a fresh Chapter 5 network.
# Author's script, not a reader step. Takes about ten minutes.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/chapter-08
CH8=$REPO/chapter-08
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
cd "$REPO/chapter-05"
./network.sh down >/dev/null 2>&1
./network.sh up >/dev/null 2>&1
( cd "$CH8/load" && npm run build >/dev/null )
run measure "$CH8/scripts/measure.sh"
cp "$CH8/load/results.csv" "$OUT/results.csv"
"$CH8/scripts/batch.sh" 2s 10 >/dev/null
run stages-2s-10 "$CH8/scripts/stages.sh" 50 20
"$CH8/scripts/batch.sh" 2s 500 >/dev/null
run stages-2s-500 "$CH8/scripts/stages.sh" 50 20
run overload bash -c "cd $CH8/load && node dist/load.js 2s/500 250 15"
./network.sh down >/dev/null 2>&1
ls -l "$OUT"
