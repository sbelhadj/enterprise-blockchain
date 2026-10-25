#!/usr/bin/env bash
#
# Appendix A, Exercise 5.5: one command up, one command down, around the network
# generator. Every step is logged with a timestamp to logs/network.log.
#   network.sh up | deployCC | addOrg ORG | status | down
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
export NETFILE=$HERE/network.json
source "$HERE/../../../network/lib/common.sh"
GEN="$NET/network.sh $NETFILE"
mkdir -p "$HERE/logs"; LOG=$HERE/logs/network.log
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
step() {  # step NAME COMMAND...: run, log the outcome, stop on failure
  local name=$1; shift
  log "start $name"
  if "$@" >> "$LOG" 2>&1; then log "done  $name"
  else log "FAIL  $name (details in logs/network.log)"; exit 1; fi
}
healthy() {  # every founder's peer and orderer answer, and peer0 is on the channel
  local o
  [ -s "$BUILD/.secrets/network.env" ] || return 1
  for o in $FOUNDERS; do
    org "$o"
    curl -sf "http://localhost:$((BASE + 443))/healthz" >/dev/null || return 1
    curl -sf "http://localhost:$((BASE + 444))/healthz" >/dev/null || return 1
  done
  use "${FOUNDERS%% *}"
  peer channel getinfo -c "$CHANNEL" >/dev/null 2>&1
}
case ${1:-} in
  up)       if healthy; then log "up: network already running, nothing to do"
            else
              [ -d "$BUILD" ] && step "clean partial network" $GEN down
              for c in generate cas identities nodes channel deploy; do
                step "$c" $GEN "$c"
              done
            fi ;;
  deployCC) step "deploy chaincode" $GEN deploy ;;
  addOrg)   step "add ${2:?organization}" $GEN add-org "$2" ;;
  status)   log "status"
            for o in $ALL_ORGS; do
              org "$o"
              p=$(curl -s "http://localhost:$((BASE + 443))/healthz" |
                jq -r '.status // "DOWN"' 2>/dev/null || echo DOWN)
              use "$o"
              h=$(peer channel getinfo -c "$CHANNEL" 2>/dev/null |
                sed 's/^Blockchain info: //' | jq -r .height 2>/dev/null || echo -)
              printf '  %-13s peer0 %-4s height %s\n' "$o" "${p:-DOWN}" "$h" |
                tee -a "$LOG"
            done ;;
  down)     step "down" $GEN down ;;
  *)        echo "usage: network.sh up|deployCC|addOrg ORG|status|down" >&2
            exit 1 ;;
esac
