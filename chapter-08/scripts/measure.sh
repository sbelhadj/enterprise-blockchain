#!/usr/bin/env bash
#
# Listing 8.3: the measurement. Three batch settings, five offered rates each,
# 20 seconds per rate, on the running Chapter 5 network. Results go to
# chapter-08/load/results.csv, one row per setting and rate.
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd) LOAD=$(cd "$(dirname "$0")/../load" && pwd)
RATES=${RATES:-10,25,50,100,150} SECONDS_=${SECONDS_:-20}

load() { (cd "$LOAD" && node dist/load.js "$@"); }
echo "== host: $(nproc) vCPU, $(free -g | awk '/Mem:/ {print $2}') GB RAM," \
  "$(uname -m), every node of the network on this one machine"
# Warm up until discovery knows both banks' peers (about 30 s on a fresh network)
until load warmup 5 2 | awk 'NR == 2 {ok = ($NF == 0)} END {exit !ok}'; do
  sleep 5
done
rm -f "$LOAD/results.csv"
first=1
for setting in "2s 10" "2s 500" "250ms 100"; do
  set -- $setting
  echo "== BatchTimeout $1, MaxMessageCount $2"
  "$S/batch.sh" "$1" "$2" | tail -1
  if [ $first = 1 ]; then load "$1/$2" "$RATES" "$SECONDS_"
  else load "$1/$2" "$RATES" "$SECONDS_" | tail -n +2; fi
  first=0
done
