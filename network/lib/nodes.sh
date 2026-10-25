#!/usr/bin/env bash
#
# Starts the orderer, state database and peer of each organization and checks the
# health of each node. Usage: nodes.sh ORG...
set -euo pipefail
source "$(dirname "$0")/common.sh"
services=() checks=()
for o in "$@"; do
  org "$o"
  if [ "$ORDERER_NODE" = true ]; then
    services+=("orderer0-$o"); checks+=("orderer0.$DOMAIN:$((BASE + 444))")
  fi
  [ "$STATEDB" = CouchDB ] && services+=("couchdb-$o")
  services+=("peer0-$o"); checks+=("peer0.$DOMAIN:$((BASE + 443))")
done
$COMPOSE up -d "${services[@]}" 2>&1 | grep -E 'Error' || true
for node in "${checks[@]}"; do
  wait_for 30 curl -sf "http://localhost:${node#*:}/healthz" || true
  printf '%-34s %s\n' "${node%:*}" \
    "$(curl -s "http://localhost:${node#*:}/healthz" | jq -r .status)"
done
