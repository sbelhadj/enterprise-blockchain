#!/usr/bin/env bash
#
# Listing L4.2: Part B, an upgrade vote. Version 2.0 of the lc definition makes
# both banks' peers mandatory endorsers. ExportBank and ImportBank approve and try
# to commit; CustomsAuthority approves later; ShippingLine never does.
set -euo pipefail
source "$(dirname "$0")/env.sh"
POLICY="AND('ExportBankMSP.peer', 'ImportBankMSP.peer')"
DEF=(-C "$CHANNEL" -n "$CC" -v 2.0 --sequence 2 --signature-policy "$POLICY")
approve() {
  use "$1"
  local id; id=$(peer lifecycle chaincode calculatepackageid \
    "$BUILD/packages/$1/$CC_LABEL.tgz")
  printf '  %-15s approves: %s\n' "$MSP" "$(peer lifecycle chaincode \
    approveformyorg -o "$ORDERER" --tls --cafile "$ORDERER_CA" "${DEF[@]}" \
    --package-id "$id" 2>&1 | grep -o 'committed with status (.*)')"
}
readiness() {
  use exportbank
  peer lifecycle chaincode checkcommitreadiness "${DEF[@]}" -O json |
    jq -r '.approvals | to_entries | map("\(.key | sub("MSP$"; ""))=\(.value)")
      | "  readiness: " + join(" ")'
}
commit() {  # commit ORG...: ExportBank commits, endorsed by the peers of ORG...
  local peers; mapfile -t peers < <(peer_args "$@")
  use exportbank
  peer lifecycle chaincode commit -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
    "${DEF[@]}" "${peers[@]}" 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .{0,140}' | head -1
}
echo "== 1. Two banks approve version 2.0 at sequence 2"
approve exportbank; approve importbank; readiness
echo "  commit with two approvals: $(commit exportbank importbank)"
echo "== 2. CustomsAuthority approves: three of four is a majority"
approve customs; readiness
echo "  commit: $(commit exportbank importbank customs)"
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n "$CC" -O json |
  jq -r '"  committed: version \(.version), sequence \(.sequence)"'
echo "== 3. The new policy at work"
echo "  endorsed by ExportBank and Customs: $(ENDORSERS='exportbank customs' \
  issue_lc LC-V2-1)"
echo "  endorsed by both banks:             $(ENDORSERS='exportbank importbank' \
  issue_lc LC-V2-2)"
echo "== 4. ShippingLine never approved version 2.0"
use shippingline user1
peer chaincode query -C "$CHANNEL" -n "$CC" -c "$(cc_args ReadLC LC-V2-2)" 2>&1 |
  grep -o -E 'chaincode definition for .{0,100}|"status":"[A-Z]+"' | head -1 |
  sed 's/"$//' | fold -s -w 78 | sed 's/^/  /' || true
