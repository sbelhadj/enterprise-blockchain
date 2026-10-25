#!/usr/bin/env bash
#
# Listing 7.7: an erasure drill. ImportBank purges the private terms of LC-2026-101;
# then every peer is asked for the terms and their hash, and the blocks are read to
# see what remains on the channel. Run after Listing 7.6.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ID=LC-2026-101
tx_json() {  # tx_json TXID FILE: the transaction as CustomsAuthority's peer has it
  use customs user1
  peer chaincode query -C "$CHANNEL" -n qscc --hex \
    -c "{\"Args\":[\"GetTransactionByID\",\"$CHANNEL\",\"$1\"]}" 2>/dev/null |
    tr -d '\n' | tr a-f A-F | basenc --base16 -d |
    configtxlator proto_decode --type protos.ProcessedTransaction > "$2"
}

echo "== 1. ImportBank purges the terms"
use importbank user1
terms_submit "${BANK_PEERS[@]}" -- PurgeTerms "$ID"
PURGE_TX=$TXID

echo "== 2. Every peer, asked for the terms and for their hash"
for o in exportbank importbank customs; do
  use $o user1
  echo "$MSP: $(terms_query ReadTerms "$ID")"
  echo "$MSP: $(terms_query TermsHash "$ID")"
done

echo "== 3. What the blocks still hold"
PUT_TX=$(cat "$CH5/channel-artifacts/put-terms.txid")
tx_json "$PUT_TX" "$CH5/channel-artifacts/put.json"
echo "-- the PutTerms transaction"
hashed_writes "$CH5/channel-artifacts/put.json" lcterms
tx_json "$PURGE_TX" "$CH5/channel-artifacts/purge.json"
echo "-- the PurgeTerms transaction"
hashed_writes "$CH5/channel-artifacts/purge.json" lcterms
