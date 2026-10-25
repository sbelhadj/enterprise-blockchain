#!/usr/bin/env bash
#
# Listing 5.7: start the three orderers and three peers, then check each one.
set -euo pipefail
source "$(dirname "$0")/env.sh"
$COMPOSE up -d orderer0-exportbank orderer0-importbank orderer0-customs \
  peer0-exportbank peer0-importbank peer0-customs 2>&1 |
  grep -E 'Started|Running|Error' || true
for node in orderer0.exportbank:7444 orderer0.importbank:8444 \
            orderer0.customs:9444 peer0.exportbank:7443 peer0.importbank:8443 \
            peer0.customs:9443; do
  for i in $(seq 30); do
    status=$(curl -s "http://localhost:${node#*:}/healthz" || true)
    [ -n "$status" ] && break; sleep 1
  done
  printf '%-32s %s\n' "${node%:*}.example.com" "$status"
done
