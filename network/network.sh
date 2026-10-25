#!/usr/bin/env bash
#
# Listing L1.3: the network generator. One network file describes the organizations;
# this script builds, extends and removes the network it describes.
#   network.sh NETWORK.json generate      write build/: Compose files, configtx.yaml
#   network.sh NETWORK.json cas           start the founders' CAs
#   network.sh NETWORK.json identities    enroll every identity; check every MSP
#   network.sh NETWORK.json nodes         start orderers, state databases and peers
#   network.sh NETWORK.json channel       create the channel and join the founders
#   network.sh NETWORK.json deploy        deploy the chaincode as a service
#   network.sh NETWORK.json up            all of the above, in order
#   network.sh NETWORK.json add-org ORG   add an organization by config update
#   network.sh NETWORK.json down          stop everything and delete build/
set -euo pipefail
NETFILE=${1:?network file}; CMD=${2:?command}; shift 2
export NETFILE
L=$(cd "$(dirname "$0")" && pwd)/lib
source "$L/common.sh"
case $CMD in
  generate)   "$L/generate.sh" ;;
  cas)        "$L/ca.sh" $FOUNDERS ;;
  identities) for o in $FOUNDERS; do "$L/enroll.sh" "$o"; done
              for o in $FOUNDERS; do "$L/check-msp.sh" "$o" | tail -1; done ;;
  nodes)      "$L/nodes.sh" $FOUNDERS ;;
  channel)    "$L/channel.sh" ;;
  deploy)     "$L/deploy.sh" ;;
  up)         for c in generate cas identities nodes channel deploy; do
                echo "== $c"; "$0" "$NETFILE" "$c"
              done ;;
  add-org)    "$L/add-org.sh" "$@" ;;
  check-msp)  "$L/check-msp.sh" "$@" ;;
  down)       if [ -s "$BUILD/.secrets/network.env" ]; then
                $COMPOSE down -v --remove-orphans 2>&1 | tail -1
              fi
              rm -rf "$BUILD"; echo "network removed" ;;
  *)          echo "unknown command: $CMD" >&2; exit 1 ;;
esac
