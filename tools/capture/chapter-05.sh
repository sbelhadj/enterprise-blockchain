#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 5. Author's script, not a reader step.
# The Compose files in chapter-05/compose are run as local processes by
# tools/native/compose-native.py (DC below), with the same environment, commands and ports.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py
export PROMETHEUS_BIN=${PROMETHEUS_BIN:-/usr/local/bin/prometheus}
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/chapter-05
CH5=$REPO/chapter-05
mkdir -p "$OUT"
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$SAMPLES#~/fabric-samples#g" -e "s#$(dirname "$REPO")#~#g"; }
run() {  # run NAME COMMAND...: capture one listing's output
  local name=$1; shift
  echo "-- $name"
  "$@" 2>&1 | clean > "$OUT/$name.txt"
}
cd "$CH5"
./network.sh down >/dev/null 2>&1

run ca-up scripts/ca-up.sh
for o in exportbank importbank customs; do run enroll-$o scripts/enroll.sh $o; done
( cd organizations/exportbank &&
  find . -path ./ca -prune -o -path ./tlsca -prune -o -path ./.ca-client -prune -o \
    -path ./ca-admin -prune -o -path ./tlsca-admin -prune -o -print | sort |
  awk -F/ 'NF <= 5' | sed -E 's/[0-9a-f]{56}([0-9a-f]{8}_sk)/...\1/' ) \
  > "$OUT/exportbank-tree.txt"       # private key file names shortened for print
openssl x509 -in organizations/importbank/lcofficer/msp/signcerts/cert.pem \
  -noout -text | grep -A1 '1.2.3.4.5.6.7.8.1' | sed 's/^ *//' > "$OUT/officer-attributes.txt"
run nodes-up scripts/nodes-up.sh
run channel scripts/channel.sh
run deploy-cc scripts/deploy-cc.sh
run lc-demo scripts/lc-demo.sh
sleep 30     # gossip reports membership changes on a 30-second cycle (Section 5.7)
run ops scripts/ops.sh
run snapshot scripts/snapshot.sh
run add-customs scripts/add-customs.sh
run failures "$REPO/tools/capture/chapter-05-failures.sh"
run down ./network.sh down

# One command up, timed, then down again
start=$(date +%s)
./network.sh up > /dev/null 2>&1
took=$(( $(date +%s) - start ))
sleep 30
{ echo "network.sh up finished in $took s"; scripts/ops.sh | sed -n 1,6p; } |
  clean > "$OUT/network-up.txt"
./network.sh down | clean >> "$OUT/network-up.txt"
ls -l "$OUT"
