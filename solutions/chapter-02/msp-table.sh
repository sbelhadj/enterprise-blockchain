#!/usr/bin/env bash
#
# Appendix A, Exercise 2.1: every certificate in the msp and tls folders of
# peer0.org2 and of Org1's admin user, one line each. Run from
# fabric-samples/test-network.
set -euo pipefail
O=organizations/peerOrganizations
cn() { sed -n 's/.*CN *= *\([^,/]*\).*/\1/p' | sed 's/\.example\.com$//'; }
row() {  # row FILE: subject CN, OU, issuer CN, key type, expiry date
  local f=$1 subj
  subj=$(openssl x509 -in "$f" -noout -subject -nameopt compat)
  printf '  %-24s %-12s %-6s %-11s %-6s %s\n' "$(basename "$(dirname "$f")")/$(
    basename "$f" | cut -c1-12)" "$(cn <<< "$subj")" \
    "$(sed -n 's/.*OU *= *\([^,/]*\).*/\1/p' <<< "$subj" | head -1)" \
    "$(openssl x509 -in "$f" -noout -issuer -nameopt compat | cn)" \
    "$(openssl x509 -in "$f" -noout -text |
      grep -o -m1 'id-ecPublicKey\|rsaEncryption\|ED25519' |
      sed 's/id-ecPublicKey/ECDSA/')" \
    "$(date -u -d "$(openssl x509 -in "$f" -noout -enddate | cut -d= -f2)" +%F)"
}
for who in "$O/org2.example.com/peers/peer0.org2.example.com" \
           "$O/org1.example.com/users/Admin@org1.example.com"; do
  echo "== ${who##*/}"
  printf '  %-24s %-12s %-6s %-11s %-6s %s\n' file subject OU issuer key expires
  find "$who/msp" "$who/tls" -name '*.pem' -o -name '*.crt' | sort |
    while read -r f; do row "$f"; done
done
A=$O/org1.example.com/users/Admin@org1.example.com/msp
echo "== Why Admin@org1 is an administrator"
openssl x509 -in "$A/signcerts/"*.pem -noout -subject -nameopt compat
grep -A2 AdminOUIdentifier "$O/org1.example.com/msp/config.yaml"
openssl verify -CAfile "$A/cacerts/"*.pem "$A/signcerts/"*.pem | sed 's#.*/##'
