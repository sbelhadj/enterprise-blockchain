#!/usr/bin/env bash
#
# Appendix A, Exercise 5.2: after ShippingLine joins (network.sh addOrg
# shippingline), commit lc at sequence 2 with a policy that needs a bank and the
# carrier, then test it. Run from the repository root.
set -euo pipefail
export NETFILE=$(cd "$(dirname "$0")" && pwd)/network.json
source "$(dirname "$0")/../../../network/lib/common.sh"
P="OR(AND('ExportBankMSP.peer','ShippingLineMSP.peer'),"
P+="AND('ImportBankMSP.peer','ShippingLineMSP.peer'))"
DEF=(-C "$CHANNEL" -n "$CC" -v 2.0 --sequence 2 --signature-policy "$P")
approve() {
  use "$1"
  local id; id=$(peer lifecycle chaincode calculatepackageid \
    "$BUILD/packages/$1/$CC_LABEL.tgz")
  printf '  %-16s approves: %s\n' "$MSP" "$(peer lifecycle chaincode \
    approveformyorg -o "$ORDERER" --tls --cafile "$ORDERER_CA" "${DEF[@]}" \
    --package-id "$id" 2>&1 | grep -o 'committed with status (.*)')"
}
send() {  # send ORG IDENTITY "ENDORSER ORGS" FUNCTION ARG...
  local who=$1 id=$2 peers; mapfile -t peers < <(peer_args $3); shift 3
  use "$who" "$id"
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" -c "$(cc_args "$@")" --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .{0,100}' | head -1 |
    sed 's/committed with status/committed/'
}
LC=(Tunis-Olive-Imports Sfax-Olive-Oil-Co ExportBankMSP 50000000 EUR
  "$(date -u -d '+180 days' +%F)" oil)

echo "== Approvals for sequence 2: LifecycleEndorsement is MAJORITY of 4, so 3"
for o in exportbank importbank shippingline; do approve "$o"; done
use exportbank
peer lifecycle chaincode checkcommitreadiness "${DEF[@]}" -O json |
  jq -r '.approvals | to_entries | map("\(.key | sub("MSP$"; ""))=\(.value)")
    | "  readiness: " + join(" ")'
mapfile -t peers < <(peer_args exportbank importbank shippingline)
echo "  commit: $(peer lifecycle chaincode commit -o "$ORDERER" --tls \
  --cafile "$ORDERER_CA" "${DEF[@]}" "${peers[@]}" 2>&1 |
  grep -o 'committed with status ([A-Z_]*)' | head -1)"
echo "== CustomsAuthority approves after the commit, so that its peer runs 2.0 too"
approve customs
echo "== IssueLC under the new policy"
echo "  LC-52A, ImportBank and Customs:      $(send importbank \
  lcofficer 'importbank customs' IssueLC LC-52A "${LC[@]}")"
echo "  LC-52B, ImportBank and ShippingLine: $(send importbank \
  lcofficer 'importbank shippingline' IssueLC LC-52B "${LC[@]}")"
echo "== AcceptLC LC-52B: the LC's own key-level policy still names both banks"
echo "  endorsed by ExportBank and ShippingLine: $(send exportbank admin \
  'exportbank shippingline' AcceptLC LC-52B)"
echo "  endorsed by ExportBank and ImportBank:   $(send exportbank admin \
  'exportbank importbank' AcceptLC LC-52B)"
