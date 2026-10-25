#!/usr/bin/env bash
#
# Captures the Appendix A outputs for Exercises 5.4, 7.1, 7.2 and 7.3 on a fresh
# Chapter 5 network run by the process runner, as tools/capture/chapter-07.sh
# does. Author's script, not a reader step. VOLRM and VOLDIR stand in for
# docker volume rm and for reading a Docker volume.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
CH5=$REPO/chapter-05 CH7=$REPO/chapter-07 S=$REPO/solutions
OUT=$REPO/captured-outputs/appendix
export VOLRM="$DC --env-file $CH5/.secrets/ca.env -f $CH5/compose/compose-ca.yaml -f $CH5/compose/compose-net.yaml volume-rm"
export VOLDIR=$REPO/work/compose-native/lcnet/volumes
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
cd "$CH5"
./network.sh down >/dev/null 2>&1
./network.sh up >/dev/null 2>&1
scripts/lc-demo.sh >/dev/null 2>&1
scripts/snapshot.sh >/dev/null 2>&1
run ex5-4-snapshot "$S/chapter-05/ex5-4/snapshot-recover.sh"
scripts/add-customs.sh >/dev/null 2>&1
( cd "$CH7/lcterms" && npm run build >/dev/null )
"$CH7/scripts/deploy-lcterms.sh" >/dev/null 2>&1
sleep 10
run ex7-1-salt "$S/chapter-07/salt.sh"
run ex7-2-erasure "$S/chapter-07/erasure-backup.sh"
run ex7-3-revoke "$S/chapter-07/revoke-timing.sh"
./network.sh down >/dev/null 2>&1
ls -l "$OUT"
