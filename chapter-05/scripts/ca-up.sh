#!/usr/bin/env bash
#
# Listing 5.2: start the six certificate authorities and wait until each answers.
set -euo pipefail
source "$(dirname "$0")/env.sh"
"$CH5/scripts/secrets.sh"
for o in exportbank importbank customs; do
  mkdir -p "$CH5/organizations/$o/ca" "$CH5/organizations/$o/tlsca"
done
$COMPOSE up -d ca-exportbank tlsca-exportbank ca-importbank tlsca-importbank \
  ca-customs tlsca-customs 2>&1 | grep -E 'Started|Running|Error' || true
for o in exportbank importbank customs; do
  org $o
  for ca in ca:$((BASE + 54)) tlsca:$((BASE + 55)); do
    name=${ca%:*} port=${ca#*:} root=$ORGDIR/${ca%:*}/ca-cert.pem
    for i in $(seq 30); do
      [ -s "$root" ] && curl -s --cacert "$root" "https://localhost:$port/cainfo" |
        grep -q '"success":true' && break
      sleep 1
    done
    cn=$(openssl x509 -in "$root" -noout -subject -nameopt multiline |
         sed -n 's/ *commonName *= //p')
    end=$(openssl x509 -in "$root" -noout -enddate | cut -d= -f2)
    printf '%-28s root %-16s valid until %s\n' "$name.$DOMAIN" "$cn" "$end"
  done
done
