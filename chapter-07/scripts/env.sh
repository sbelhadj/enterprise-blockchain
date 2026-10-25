#!/usr/bin/env bash
#
# Sourced by the Chapter 7 scripts: Chapter 5's settings plus the lcterms services.
CH7=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$CH7/../chapter-05/scripts/env.sh"
COMPOSE="$COMPOSE -f $CH7/compose/compose-lcterms.yaml"

tls_cert() {  # tls_cert ORG NAME HOSTS: a key pair from ORG's TLS CA into NAME/tls
  org "$1"
  local name=$2 hosts=$3 s dir=$ORGDIR/$2
  export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
  local ca=(--caname "tlsca-$ORG" --tls.certfiles "$ORGDIR/tlsca/ca-cert.pem")
  s=$(openssl rand -hex 16)
  fabric-ca-client register "${ca[@]}" -M "$ORGDIR/tlsca-admin/msp" \
    -u "https://localhost:$((BASE + 55))" --id.name "$name" --id.secret "$s" \
    --id.type client >/dev/null 2>&1
  fabric-ca-client enroll "${ca[@]}" \
    -u "https://$name:$s@localhost:$((BASE + 55))" \
    -M "$dir/tls-msp" --enrollment.profile tls --csr.hosts "$hosts" >/dev/null 2>&1
  mkdir -p "$dir/tls"
  cp "$dir"/tls-msp/signcerts/*.pem "$dir/tls/server.crt"
  cp "$dir"/tls-msp/keystore/*_sk "$dir/tls/server.key"
  rm -rf "$dir/tls-msp"
}

terms_json() {  # terms_json JSON: the transient map the peer CLI expects
  jq -cn --arg t "$1" '{terms: ($t | @base64)}'
}

BANK_PEERS=(--peerAddresses localhost:7051
  --tlsRootCertFiles "$CH5/organizations/exportbank/msp/tlscacerts/tlsca.pem"
  --peerAddresses localhost:8051
  --tlsRootCertFiles "$CH5/organizations/importbank/msp/tlscacerts/tlsca.pem")

# terms_submit PEERS... -- FUNCTION ID [TRANSIENT]: prints the status, sets TXID
terms_submit() {
  local peers=() out
  while [ "$1" != -- ]; do peers+=("$1"); shift; done; shift
  local fn=$1 id=$2 tr=${3:-}
  out=$(peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
    -C "$CHANNEL" -n lcterms "${peers[@]}" -c "$(lc_args "$fn" "$id")" \
    ${tr:+--transient "$tr"} --waitForEvent 2>&1)
  TXID=$(sed -n 's/.*txid \[\([0-9a-f]*\)\].*/\1/p' <<< "$out" | head -1)
  grep -o -m1 -E 'committed with status \([A-Z_]+\)|Error: .*' <<< "$out"
}

terms_query() {  # terms_query FUNCTION ID [TRANSIENT]: evaluate on the current peer
  peer chaincode query -C "$CHANNEL" -n lcterms -c "$(lc_args "$1" "$2")" \
    ${3:+--transient "$3"} 2>&1 | grep -v InitCmdFactory |
    sed -E 's/.*message:"([^"]*)".*/\1/; s/^[A-Z_]+ failed: //
            s/transaction ID: [0-9a-f]+: //'
}

hex() { base64 -d | basenc --base16 -w0 | tr A-F a-f; }

# hashed_writes TX.json NAMESPACE: the private writes as the channel sees them
hashed_writes() {
  local A='.transactionEnvelope.payload.data.actions[0].payload.action'
  jq -r --arg ns "$2" "$A.proposal_response_payload.extension.results.ns_rwset[] |
    select(.namespace == \$ns) | .collection_hashed_rwset[] |
    \"\(.collection_name) \(.hashed_rwset)\"" "$1" | while read -r c set; do
    base64 -d <<< "$set" | configtxlator proto_decode --type kvrwset.HashedRWSet |
      jq -r '.hashed_writes[] | [.key_hash, .value_hash, .is_purge] | join("|")' |
      while IFS='|' read -r k v p; do
        echo "$c: key hash $(hex <<< "$k" | cut -c1-16)..., purge $p"
        [ -z "$v" ] || echo "  value hash $(hex <<< "$v")"
      done
  done
}
