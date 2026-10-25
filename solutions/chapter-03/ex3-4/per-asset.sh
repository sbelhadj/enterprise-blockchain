#!/usr/bin/env bash
#
# Appendix A, Exercise 3.4: with a third organization on the channel, the
# chaincode-level MAJORITY policy is two of three, but each LC's key-level policy
# still names both banks. Run from the repository root after
#   network/network.sh solutions/chapter-03/ex3-4/network.json up
#   network/network.sh solutions/chapter-03/ex3-4/network.json add-org customs
set -euo pipefail
export NETFILE=$(cd "$(dirname "$0")" && pwd)/network.json
source "$(dirname "$0")/../../../network/lib/common.sh"
send() {  # send IDENTITY_ORG IDENTITY ENDORSER_ORGS FUNCTION ARG...
  local who=$1 id=$2 peers; mapfile -t peers < <(peer_args $3); shift 3
  use "$who" "$id"
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" -c "$(cc_args "$@")" --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .{0,100}' | head -1 |
    sed 's/committed with status/committed/'
}
EXPIRY=$(date -u -d '+180 days' +%F)
LC=(Tunis-Olive-Imports Sfax-Olive-Oil-Co ExportBankMSP 50000000 EUR "$EXPIRY" oil)

use exportbank
peer channel fetch config "$BUILD/c.pb" -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -c "$CHANNEL" >/dev/null 2>&1
echo "== Application organizations: $(configtxlator proto_decode --input \
  "$BUILD/c.pb" --type common.Block | jq -r '.data.data[0].payload.data.config
  .channel_group.groups.Application.groups | keys | join(" ")')"
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n "$CC" -O json |
  jq -r '"== lc \(.version) at sequence \(.sequence), policy " +
    (.validation_parameter | @base64d | gsub("[^A-Za-z/]"; ""))'
echo "== IssueLC LC-34, endorsed by ImportBank and Customs"
echo "  $(send importbank lcofficer 'importbank customs' IssueLC LC-34 "${LC[@]}")"
echo "== AcceptLC LC-34, endorsed by ExportBank and Customs"
echo "  $(send exportbank admin 'exportbank customs' AcceptLC LC-34)"
echo "== AcceptLC LC-34, endorsed by ExportBank and ImportBank"
echo "  $(send exportbank admin 'exportbank importbank' AcceptLC LC-34)"
use customs
peer chaincode query -C "$CHANNEL" -n "$CC" -c "$(cc_args ReadLC LC-34)" \
  2>/dev/null |
  jq -c "{id, status, advisingBank}" | sed "s/^/customs reads: /"
