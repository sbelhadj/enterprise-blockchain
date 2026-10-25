#!/usr/bin/env bash
#
# Listing 7.6: private terms end to end. ImportBank stores the terms of LC-2026-101
# in lcBankTerms; each organization tries to read them; CustomsAuthority, which only
# holds the hash, checks two copies against it; and the block shows what was stored.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ID=LC-2026-101
TERMS='{"settlementAccount":"ACC-IMP-0042","feeBps":35,"discountRateBps":410}'

echo "== 1. ImportBank stores the terms as transient data"
use importbank user1
terms_submit "${BANK_PEERS[@]}" -- PutTerms "$ID" "$(terms_json "$TERMS")"
PUT_TX=$TXID; echo "$PUT_TX" > "$CH5/channel-artifacts/put-terms.txid"

echo "== 2. Each organization reads them from its own peer"
for o in exportbank importbank customs; do
  use $o user1; echo "$MSP: $(terms_query ReadTerms "$ID")"
done

echo "== 3. The hash each peer holds, and the same hash computed here"
for o in exportbank importbank customs; do
  use $o user1; echo "$MSP: $(terms_query TermsHash "$ID")"
done
echo "sha256 of the canonical terms: $(jq -cS . <<< "$TERMS" | tr -d '\n' |
  sha256sum | cut -d' ' -f1)"

echo "== 4. CustomsAuthority checks a copy it was given, and a tampered one"
use customs user1
echo "copy:     $(terms_query VerifyTerms "$ID" "$(terms_json "$TERMS")")"
echo "tampered: $(terms_query VerifyTerms "$ID" "$(terms_json "${TERMS/35/25}")")"

echo "== 5. What the transaction on CustomsAuthority's peer contains"
J=$CH5/channel-artifacts/put-terms.json
peer chaincode query -C "$CHANNEL" -n qscc --hex \
  -c "{\"Args\":[\"GetTransactionByID\",\"$CHANNEL\",\"$PUT_TX\"]}" 2>/dev/null |
  tr -d '\n' | tr a-f A-F | basenc --base16 -d |
  configtxlator proto_decode --type protos.ProcessedTransaction > "$J"
A='.transactionEnvelope.payload.data.actions[0].payload'
jq -r "$A.chaincode_proposal_payload.input.chaincode_spec.input.args |
  \"arguments: \" + ([.[] | @base64d] | join(\" \"))" "$J"
hashed_writes "$J" lcterms
echo "occurrences of the account number: $(grep -c ACC-IMP-0042 "$J" || true)"

echo "== 6. A note only ImportBank holds, in its implicit collection"
use importbank user1
NOTE=$(jq -cn --arg n 'Applicant within limit; collateral 20 percent' \
  '{note: ($n | @base64)}')
IMPORT_PEER=(--peerAddresses localhost:8051 --tlsRootCertFiles
  "$CH5/organizations/importbank/msp/tlscacerts/tlsca.pem")
terms_submit "${IMPORT_PEER[@]}" -- PutCreditNote "$ID" "$NOTE"
echo "ImportBankMSP: $(terms_query ReadCreditNote "$ID")"
use exportbank user1; echo "ExportBankMSP: $(terms_query ReadCreditNote "$ID")"
