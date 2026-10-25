#!/usr/bin/env bash
#
# Listing 5.15: the whole network in one command, and its clean removal.
#   ./network.sh up     CAs, identities, nodes, channel and chaincode
#   ./network.sh down   stop everything, delete volumes and generated material
set -euo pipefail
cd "$(dirname "$0")"
S=./scripts
case ${1:-} in
  up)
    $S/ca-up.sh
    for o in exportbank importbank customs; do $S/enroll.sh "$o"; done
    $S/nodes-up.sh
    $S/channel.sh
    $S/deploy-cc.sh
    ;;
  down)
    source $S/env.sh
    if [ -s .secrets/ca.env ]; then
      $COMPOSE down -v --remove-orphans 2>&1 | tail -1
    fi
    rm -rf organizations channel-artifacts packages snapshots .secrets
    echo "network removed"
    ;;
  *)
    echo "usage: $0 up|down" >&2; exit 1 ;;
esac
