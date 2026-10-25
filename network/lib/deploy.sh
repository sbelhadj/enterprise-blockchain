#!/usr/bin/env bash
#
# Deploys the network file's chaincode as a service. Each organization packages a
# connection.json for its own chaincode server, installs it, starts the server with
# the package ID and approves the definition; then one administrator commits it.
# Usage: deploy.sh [ORG...] (default: the founders). NO_COMMIT=1 only approves.
set -euo pipefail
source "$(dirname "$0")/common.sh"
ORGS=${*:-$FOUNDERS}
SEQUENCE=${SEQUENCE:-$(cfg '.chaincode.sequence // 1')}
DEF=()       # optional parts of the definition: a policy, private collections
policy=$(cfg '.chaincode.policy // empty')
[ -n "$policy" ] && DEF+=(--signature-policy "$policy")
coll=$(cfg '.chaincode.collections // empty')
[ -n "$coll" ] && DEF+=(--collections-config "$LAB/$coll")

package() {  # package: metadata.json and a code archive with connection.json only
  local dir=$BUILD/packages/$ORG
  rm -rf "$dir"; mkdir -p "$dir/src"
  jq -n --arg addr "$CC.$DOMAIN:$((BASE + 99))" \
    --rawfile root "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    '{address: $addr, dial_timeout: "10s", tls_required: true,
      client_auth_required: false, root_cert: $root}' > "$dir/src/connection.json"
  # the CouchDB indexes, if the chaincode has any
  [ -d "$CC_PATH/META-INF" ] && cp -r "$CC_PATH/META-INF" "$dir/src/"
  tar -C "$dir/src" -czf "$dir/code.tar.gz" connection.json \
    $([ -d "$dir/src/META-INF" ] && echo META-INF)
  jq -n --arg label "$CC_LABEL" '{type: "ccaas", label: $label}' \
    > "$dir/metadata.json"
  tar -C "$dir" -czf "$dir/$CC_LABEL.tgz" metadata.json code.tar.gz
  echo "$dir/$CC_LABEL.tgz"
}

for o in $ORGS; do
  use "$o"
  pkg=$(package)
  peer lifecycle chaincode install "$pkg" >/dev/null 2>&1 || true   # once per peer
  id=$(peer lifecycle chaincode calculatepackageid "$pkg")
  env "CC_PACKAGE_ID_${o^^}=$id" $COMPOSE up -d "$CC-$o" 2>&1 | grep Error || true
  approve() {
    peer lifecycle chaincode approveformyorg -o "$ORDERER" --tls \
      --cafile "$ORDERER_CA" -C "$CHANNEL" -n "$CC" -v "$CC_VERSION" \
      --sequence "$SEQUENCE" --package-id "$id" "${DEF[@]}" 2>&1 |
      grep -o 'committed with status (.*)'
  }
  # a channel created seconds ago may still be electing its Raft leader: retry
  for try in 1 2 3 4 5; do r=$(approve) && break; r='approval failed'; sleep 5; done
  printf '%-16s %s\n' "$MSP" "$r"
done
[ -n "${NO_COMMIT:-}" ] && exit 0

use "${FOUNDERS%% *}"
mapfile -t PEERS < <(peer_args $FOUNDERS)
use "${FOUNDERS%% *}"
peer lifecycle chaincode commit -o "$ORDERER" --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL" -n "$CC" -v "$CC_VERSION" --sequence "$SEQUENCE" "${DEF[@]}" \
  "${PEERS[@]}" \
  2>&1 | grep -o 'committed with status (.*) at .*' | sed 's/^/commit: /'
peer lifecycle chaincode querycommitted -C "$CHANNEL" -n "$CC" -O json |
  jq -r '"committed: version \(.version), sequence \(.sequence)",
    "approved by: " +
    ([.approvals | to_entries[] | select(.value) | .key] | join(" "))'
