#!/usr/bin/env bash
#
# Listing L3.8: Part D milestone. Stop the service, let the MRO record two events
# with the peer CLI while it is down, restart it twice, and count what it applies.
set -euo pipefail
source "$(dirname "$0")/env.sh"
S=${1:-ESN-1001} LOG=$SVC/data/service.log
since() { tail -n +"$(( $1 + 1 ))" "$LOG" | grep '^\[listener\]' || true; }
echo "== the service stops"
service_stop
echo "== the MRO records two events while it is down"
echo "REMOVE $S: $(cli_submit mro RecordEvent "$S" REMOVE '' '' '')"
doc=$(printf 'EASA Form 1, repair of %s' "$S" | sha256sum | cut -d' ' -f1)
echo "REPAIR $S: $(cli_submit mro RecordEvent "$S" REPAIR '' '' "$doc")"
echo "== first restart"
n=$(wc -l < "$LOG"); service_start; sleep 5; since "$n"
echo "== second restart"
service_stop
n=$(wc -l < "$LOG"); service_start; sleep 5
echo "listener lines after the second restart: $(since "$n" | wc -l)"
echo "== the maintenance system's record of $S"
api amel GET /maintenance/parts | cut -d' ' -f2- |
  jq -c --arg s "$S" '.[] | select(.serial == $s) | {serial, status, aircraft}'
