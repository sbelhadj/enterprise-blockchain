# Helpers for Chapter 2: read transactions and blocks from a peer's own ledger through qscc,
# the peer's built-in query system chaincode. Scratch files go to $WORK. Unlike a block fetched from the orderer, these
# carry the validation result the peer recorded. Source after chapter-01/org1-env.sh.

# qscc FUNCTION ARG -> decoded protobuf bytes on stdout
qscc() {
  peer chaincode query -C mychannel -n qscc --hex \
    -c "{\"Args\":[\"$1\",\"mychannel\",\"$2\"]}" | tr -d '\n' | tr a-f A-F | basenc --base16 -d
}

# show_tx TXID: block and position, validation code, creator, endorsers, the reads in every
# namespace, and the read-write set of the basic chaincode
show_tx() {
  local tx=$1
  qscc GetBlockByTxID "$tx" > "$WORK/tx-block.pb"
  configtxlator proto_decode --type common.Block --input "$WORK/tx-block.pb" |
    jq -r --arg tx "$tx" '"block: \(.header.number), position in block: \(
      [.data.data[].payload.header.channel_header.tx_id] | index($tx))"'
  qscc GetTransactionByID "$tx" > "$WORK/tx.pb"
  configtxlator proto_decode --type protos.ProcessedTransaction --input "$WORK/tx.pb" > "$WORK/tx.json"
  jq -r '"validation code: \(.validationCode)",
         "creator: \(.transactionEnvelope.payload.header.signature_header.creator.mspid)"' "$WORK/tx.json"
  for e in $(jq -r '.transactionEnvelope.payload.data.actions[0].payload.action.endorsements[].endorser' "$WORK/tx.json"); do
    echo "$e" | base64 -d > "$WORK/endorser.pb"
    configtxlator proto_decode --type msp.SerializedIdentity --input "$WORK/endorser.pb" |
      jq -r '"endorsed by: \(.mspid)"'
  done
  jq -c '[.transactionEnvelope.payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[]
          | {(.namespace): [.rwset.reads[] | "\(.key) read at \(.version.block_num):\(.version.tx_num)"]}] | add' "$WORK/tx.json"
  jq '.transactionEnvelope.payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[]
      | select(.namespace == "basic") | .rwset
      | {reads: [.reads[] | {key, version: "\(.version.block_num):\(.version.tx_num)"}],
         writes: [.writes[] | {key, value: (.value | @base64d)}]}' "$WORK/tx.json"
}
