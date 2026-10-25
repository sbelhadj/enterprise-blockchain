#!/usr/bin/env bash
#
# Part E load run: a new part, installed, then flight cycles at RATE per second
# for SECONDS seconds, all through the API (service/src/load.ts).
set -euo pipefail
source "$(dirname "$0")/env.sh"
S=${1:-ESN-2001} RATE=${2:-5} SECONDS_=${3:-10}
cert=$(printf 'EASA Form 1, %s' "$S" | sha256sum | cut -d' ' -f1)
api sofia POST /parts "$(jq -cn --arg s "$S" --arg h "$cert" '{serial: $s,
  partNumber: "FAN-BLADE-2", description: "Fan blade", certHash: $h}')" >/dev/null
api amel POST "/parts/$S/events" \
  '{"type":"INSTALL","aircraft":"TS-IMW","position":"ENG2-FAN-07"}' >/dev/null
KEY=$(grep '^AMEL=' "$SVC/.secrets/api-keys.env" | cut -d= -f2) \
  node "$SVC/dist/load.js" "$S" "$RATE" "$SECONDS_"
