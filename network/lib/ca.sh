#!/usr/bin/env bash
#
# Starts the identity CA and TLS CA of each organization and waits until each
# answers. Usage: ca.sh ORG...
set -euo pipefail
source "$(dirname "$0")/common.sh"
services=()
for o in "$@"; do
  mkdir -p "$BUILD/organizations/$o/ca" "$BUILD/organizations/$o/tlsca"
  services+=("ca-$o" "tlsca-$o")
done
$COMPOSE up -d "${services[@]}" 2>&1 | grep -E 'Error' || true
for o in "$@"; do
  org "$o"
  for ca in ca:$((BASE + 54)) tlsca:$((BASE + 55)); do
    name=${ca%:*} port=${ca#*:} root=$ORGDIR/${ca%:*}/ca-cert.pem
    wait_for 30 eval "[ -s $root ] && curl -s --cacert $root \
      https://localhost:$port/cainfo | grep -q '\"success\":true'"
    end=$(openssl x509 -in "$root" -noout -enddate | cut -d= -f2)
    printf '%-30s port %-6s root valid until %s\n' "$name.$DOMAIN" "$port" "$end"
  done
done
