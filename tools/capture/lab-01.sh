#!/usr/bin/env bash
#
# Captures the outputs printed in Lab 1, from a clean start. Author's script, not a
# reader step. CouchDB is not available on the authoring machine, so the peers run
# with LevelDB (STATEDB=goleveldb); no printed output depends on the state database.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py STATEDB=goleveldb
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/lab-01
LAB=$REPO/lab-01-port-network
N="$REPO/network/network.sh $LAB/network.json"
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$REPO")#~#g"; }
run() { local n=$1; shift; echo "-- $n"; "$@" 2>&1 | clean > "$OUT/$n.txt"; }
( cd "$LAB/shipment-chaincode" && npm run build >/dev/null )
$N down >/dev/null 2>&1
run design "$LAB/scripts/check-design.sh"
run design-fail "$LAB/scripts/check-design.sh" "$LAB/examples/two-orderers.json"
run generate $N generate
run cas $N cas
run identities $N identities
run check-msp $N check-msp customs
run nodes $N nodes
run channel $N channel
sleep 5
run status "$LAB/scripts/status.sh"
run deploy $N deploy
sleep 30                                   # gossip membership for discovery
run smoke "$LAB/scripts/smoke.sh"
run resilience "$LAB/scripts/resilience.sh"
run add-org $N add-org forwarder
sleep 10
run forwarder "$LAB/scripts/forwarder.sh"
run failures "$LAB/scripts/failures.sh"
$N down >/dev/null 2>&1
ls -l "$OUT"
