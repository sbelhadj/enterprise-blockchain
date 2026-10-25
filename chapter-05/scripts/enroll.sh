#!/usr/bin/env bash
#
# Listing 5.3: register and enroll every identity of one organization with its two
# CAs, and build the organization's MSP.
# Usage: enroll.sh exportbank|importbank|customs
# Enrollment secrets are random, used once and never written down.
set -euo pipefail
source "$(dirname "$0")/env.sh"
org "$1"
set -a; source "$CH5/.secrets/ca.env"; set +a
CA_PORT=$((BASE + 54)) TLS_PORT=$((BASE + 55))
CA_ROOT=$ORGDIR/ca/ca-cert.pem TLS_ROOT=$ORGDIR/tlsca/ca-cert.pem
CACERT=localhost-$CA_PORT-ca-$ORG.pem           # the name enroll gives the CA root
export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
idca()  { fabric-ca-client "$@" --caname "ca-$ORG" --tls.certfiles "$CA_ROOT" \
            2>/dev/null; }
tlsca() { fabric-ca-client "$@" --caname "tlsca-$ORG" --tls.certfiles "$TLS_ROOT" \
            2>/dev/null; }
secret() { openssl rand -hex 16; }

# 1. Enroll each CA's bootstrap administrator (under organizations/, not in Git)
pw=${ORG^^}_CA_ADMINPW
idca enroll -u "https://caadmin:${!pw}@localhost:$CA_PORT" -M "$ORGDIR/ca-admin/msp"
pw=${ORG^^}_TLSCA_ADMINPW
tlsca enroll -u "https://caadmin:${!pw}@localhost:$TLS_PORT" \
  -M "$ORGDIR/tlsca-admin/msp"

# 2. The organization's MSP: who its CAs are, and which OU marks which role
mkdir -p "$ORGDIR/msp/cacerts" "$ORGDIR/msp/tlscacerts"
cp "$CA_ROOT" "$ORGDIR/msp/cacerts/$CACERT"
cp "$TLS_ROOT" "$ORGDIR/msp/tlscacerts/tlsca.pem"
{
  echo 'NodeOUs:'
  echo '  Enable: true'
  for role in client peer admin orderer; do
    echo "  ${role^}OUIdentifier:"
    echo "    Certificate: cacerts/$CACERT"
    echo "    OrganizationalUnitIdentifier: $role"
  done
} > "$ORGDIR/msp/config.yaml"

issue() {  # issue NAME TYPE TLSFILE [HOSTS] [ATTRS]: signing identity and TLS pair
  local name=$1 type=$2 tlsfile=$3 hosts=${4:-} attrs=${5:-} s
  s=$(secret)
  idca register -M "$ORGDIR/ca-admin/msp" -u "https://localhost:$CA_PORT" \
    --id.name "$name" --id.secret "$s" --id.type "$type" \
    ${attrs:+--id.attrs "$attrs"} >/dev/null
  idca enroll -u "https://$name:$s@localhost:$CA_PORT" -M "$ORGDIR/$name/msp"
  cp "$ORGDIR/msp/config.yaml" "$ORGDIR/$name/msp/config.yaml"
  if [ "$tlsfile" != none ]; then tls_pair "$name" "$type" "$tlsfile" "$hosts"; fi
}
tls_pair() {  # tls_pair NAME TYPE FILE [HOSTS]: a TLS key pair from the TLS CA
  local name=$1 type=$2 file=$3 hosts=${4:-} dir=$ORGDIR/$1 s
  s=$(secret)
  tlsca register -M "$ORGDIR/tlsca-admin/msp" -u "https://localhost:$TLS_PORT" \
    --id.name "$name" --id.secret "$s" --id.type "$type" >/dev/null
  tlsca enroll -u "https://$name:$s@localhost:$TLS_PORT" -M "$dir/tls-msp" \
    --enrollment.profile tls ${hosts:+--csr.hosts "$hosts"}
  mkdir -p "$dir/tls"
  cp "$dir"/tls-msp/signcerts/*.pem "$dir/tls/$file.crt"
  cp "$dir"/tls-msp/keystore/*_sk "$dir/tls/$file.key"
  cp "$TLS_ROOT" "$dir/tls/ca.crt"
  rm -rf "$dir/tls-msp"
}

# 3. Nodes, administrator, users and the chaincode server
PEERS=peer0; [ "$ORG" = exportbank ] && PEERS="peer0 peer1"   # peer1: Section 5.8
for p in $PEERS; do issue "$p" peer server "$p.$DOMAIN,localhost"; done
issue orderer0 orderer server "orderer0.$DOMAIN,localhost"
issue admin admin client localhost              # TLS client certificate: osnadmin
issue user1 client none
if [ "$ORG" = importbank ]; then
  issue lcofficer client none "" 'lc.role=issuer:ecert'     # Chapter 3's LC officer
fi
tls_pair lc client server "lc.$DOMAIN,localhost"      # the chaincode server (CCaaS)

# 4. What was issued: name, role (OU) and the host names in the TLS certificate
for d in "$ORGDIR"/*/msp/signcerts; do
  id=$(basename "$(dirname "$(dirname "$d")")")
  case $id in ca|tlsca|ca-admin|tlsca-admin) continue ;; esac
  ou=$(openssl x509 -in "$d/cert.pem" -noout -subject |
       grep -o 'OU *= *[a-z]*' | tail -1)
  tls=$(ls "$ORGDIR/$id"/tls/*.crt 2>/dev/null | grep -v '/ca.crt' || true)
  sans=$([ -z "$tls" ] ||
         openssl x509 -in "$tls" -noout -ext subjectAltName | tail -1)
  printf '%-10s %-8s tls: %s\n' "$id" "${ou##* }" "$(echo "${sans:--}" | xargs)"
done
