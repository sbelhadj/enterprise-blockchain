#!/usr/bin/env bash
#
# Listing L3.6: Part C milestones, through the API only. Three users act under their
# own identities, mistakes come back as HTTP errors a client can act on, and six
# concurrent updates of one part all commit, some after an MVCC retry.
set -euo pipefail
source "$(dirname "$0")/env.sh"
S=${1:-ESN-1001}
cert=$(printf 'EASA Form 1, %s' "$S" | sha256sum | cut -d' ' -f1)
show() {  # show LABEL "STATUS JSON": the status and what matters in the body
  printf '%-24s %s %s\n' "$1" "${2%% *}" "$(jq -r 'if .detail then .detail
    elif .txId then "block \(.block), attempts \(.attempts)" else .error end' \
    <<< "${2#* }" 2>/dev/null)"
}
show "sofia registers $S" "$(api sofia POST /parts "$(jq -cn --arg s "$S" \
  --arg h "$cert" '{serial: $s, partNumber: "HPT-BLADE-7",
  description: "HP turbine blade, stage 1", certHash: $h}')")"
show "amel installs it" "$(api amel POST "/parts/$S/events" \
  '{"type":"INSTALL","aircraft":"TS-IMW","position":"ENG1-HPT-STG1"}')"
show "karim reports cycles" "$(api karim POST "/parts/$S/cycles" '{"cycles":2}')"
show "amel repairs it" "$(api amel POST "/parts/$S/events" '{"type":"REPAIR"}')"
show "amel reads ESN-9999" "$(api amel GET /parts/ESN-9999)"
show "no API key" "$(curl -s "$URL/parts/$S" -w ' %{http_code}' |
  sed -E 's/^(.*) ([0-9]{3})$/\2 \1/')"

echo "== three cycle reports for $S at the same moment"
for i in 1 2 3; do
  api amel POST "/parts/$S/cycles" '{"cycles":1}' > "$SVC/data/c$i" &
done
wait
for i in 1 2 3; do
  show "  report $i" "$(cat "$SVC/data/c$i")"; rm "$SVC/data/c$i"
done
api amel GET "/parts/$S" | cut -d' ' -f2- |
  jq -c '{serial, status, aircraft, cycles}'
