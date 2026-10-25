#!/usr/bin/env bash
#
# Captures the output of Listing 6.2 on a fresh Chapter 5 network. Author's script.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
export SAMPLES=${SAMPLES:-$HOME/fabric-samples} FABRIC_SAMPLES=${SAMPLES:-$HOME/fabric-samples}
export DC=$REPO/tools/native/compose-native.py
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"
OUT=$REPO/captured-outputs/chapter-06
mkdir -p "$OUT"
cd "$REPO/chapter-05"
./network.sh down >/dev/null 2>&1
./network.sh up >/dev/null 2>&1
"$REPO/chapter-06/check-design.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$OUT/check-design.txt"
./network.sh down >/dev/null 2>&1
cat "$OUT/check-design.txt"
