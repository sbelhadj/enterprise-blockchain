#!/usr/bin/env bash
#
# Listing L1.5: checks every identity of one organization: its role (the OU that
# NodeOUs maps), that its certificate chains to the organization's CA, and the
# host names in its TLS certificate, which chains to the TLS CA.
# Usage: check-msp.sh ORG
set -euo pipefail
source "$(dirname "$0")/common.sh"
org "$1"
CA=$(ls "$ORGDIR"/msp/cacerts/*.pem) TLSCA=$ORGDIR/msp/tlscacerts/tlsca.pem
fail=0
printf '%-10s %-8s %-6s %-6s %s\n' identity role chain tls 'TLS host names'
for d in "$ORGDIR"/*/msp/signcerts; do
  id=$(basename "$(dirname "$(dirname "$d")")")
  case $id in ca|tlsca|ca-admin|tlsca-admin) continue ;; esac
  cert=$d/cert.pem
  role=$(openssl x509 -in "$cert" -noout -subject | grep -o 'OU *= *[a-z]*' |
         tail -1 | sed 's/.*= *//')
  chain=$(openssl verify -CAfile "$CA" "$cert" >/dev/null 2>&1 && echo ok ||
          echo FAIL)
  tls=- names=-
  crt=$(ls "$ORGDIR/$id"/tls/*.crt 2>/dev/null | grep -v /ca.crt || true)
  if [ -n "$crt" ]; then
    tls=$(openssl verify -CAfile "$TLSCA" "$crt" >/dev/null 2>&1 && echo ok ||
          echo FAIL)
    names=$(openssl x509 -in "$crt" -noout -ext subjectAltName | tail -1 | xargs)
  fi
  expected=$(case $id in peer*) echo peer ;; orderer*) echo orderer ;;
             admin) echo admin ;; *) echo client ;; esac)
  [ "$role" = "$expected" ] && [ "$chain" = ok ] && [ "$tls" != FAIL ] || fail=1
  printf '%-10s %-8s %-6s %-6s %s\n' "$id" "$role" "$chain" "$tls" "$names"
done
[ $fail = 0 ] && echo "$MSP: every identity has the expected role and chain" ||
  { echo "$MSP: check FAILED"; exit 1; }
