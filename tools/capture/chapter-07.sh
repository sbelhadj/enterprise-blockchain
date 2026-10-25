#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 7 on a fresh Chapter 5 network with
# CustomsAuthority added (Section 5.9). Author's script, not a reader step.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/chapter-07
CH7=$REPO/chapter-07
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
cd "$REPO/chapter-05"
./network.sh down >/dev/null 2>&1
./network.sh up >/dev/null 2>&1
scripts/lc-demo.sh >/dev/null 2>&1
scripts/add-customs.sh >/dev/null 2>&1
( cd "$CH7/lcterms" && npm run build >/dev/null ) && ( cd "$CH7/audit" && npm run build >/dev/null )
run deploy-lcterms "$CH7/scripts/deploy-lcterms.sh"
run private-terms "$CH7/scripts/private-terms.sh"
run erasure "$CH7/scripts/erasure.sh"
run revoke "$CH7/scripts/revoke.sh"
run audit bash -c "cd $CH7/audit && npm run --silent audit"
run mtls "$CH7/scripts/mtls-check.sh"
./network.sh down >/dev/null 2>&1
ls -l "$OUT"
