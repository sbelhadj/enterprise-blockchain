#!/usr/bin/env bash
#
# Listing L3.2: Part B identities. Each API user gets a Fabric identity from their
# own organization's CA, stored in the service's wallet readable by the service
# account only, and an API key of which the service keeps only the hash.
set -euo pipefail
source "$(dirname "$0")/env.sh"
umask 077
mkdir -p "$SVC/wallet" "$SVC/.secrets" "$SVC/data"
: > "$SVC/.secrets/api-keys.env"
users='[]'
for entry in sofia:partsmaker karim:mro amel:airline maintsync:airline; do
  u=${entry%:*}; org "${entry#*:}"
  export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
  CA=(--caname "ca-$ORG" --tls.certfiles "$ORGDIR/ca/ca-cert.pem")
  s=$(openssl rand -hex 16)
  fabric-ca-client register "${CA[@]}" -M "$ORGDIR/ca-admin/msp" \
    -u "https://localhost:$((BASE + 54))" --id.name "$u" --id.secret "$s" \
    --id.type client >/dev/null 2>&1
  fabric-ca-client enroll "${CA[@]}" -u "https://$u:$s@localhost:$((BASE + 54))" \
    -M "$SVC/wallet/$u/msp" >/dev/null 2>&1
  cp "$SVC/wallet/$u"/msp/signcerts/cert.pem "$SVC/wallet/$u/cert.pem"
  cp "$SVC/wallet/$u"/msp/keystore/*_sk "$SVC/wallet/$u/key.pem"
  rm -rf "$SVC/wallet/$u/msp"
  key=$(openssl rand -hex 24)
  echo "${u^^}=$key" >> "$SVC/.secrets/api-keys.env"
  users=$(jq -c --arg u "$u" --arg o "${entry#*:}" --arg h \
    "$(printf %s "$key" | sha256sum | cut -d' ' -f1)" \
    '. + [{user: $u, org: $o, keyHash: $h}]' <<< "$users")
  printf '%-10s %-14s %-8s key %s\n' "$u" "$MSP" \
    "$(openssl x509 -in "$SVC/wallet/$u/cert.pem" -noout -subject |
       grep -o 'OU *= *client' | sed 's/.*= *//')" \
    "$(stat -c '%A' "$SVC/wallet/$u/key.pem")"
done
jq . <<< "$users" > "$SVC/.secrets/api-users.json"
echo "api-users.json: $(jq length "$SVC/.secrets/api-users.json") users," \
  "hashes only"
