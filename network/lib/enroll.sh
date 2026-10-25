#!/usr/bin/env bash
#
# Registers and enrolls every identity of one organization with its two CAs and
# builds the organization's MSP. Enrollment secrets are random, used once and never
# written down. Usage: enroll.sh ORG
set -euo pipefail
source "$(dirname "$0")/common.sh"
org "$1"
set -a; source "$BUILD/.secrets/network.env"; set +a
CA_PORT=$((BASE + 54)) TLS_PORT=$((BASE + 55))
CA_ROOT=$ORGDIR/ca/ca-cert.pem TLS_ROOT=$ORGDIR/tlsca/ca-cert.pem
CACERT=localhost-$CA_PORT-ca-$ORG.pem           # the name enroll gives the CA root
export FABRIC_CA_CLIENT_HOME=$ORGDIR/.ca-client
idca()  { fabric-ca-client "$@" --caname "ca-$ORG" --tls.certfiles "$CA_ROOT" \
            2>/dev/null; }
tlsca() { fabric-ca-client "$@" --caname "tlsca-$ORG" --tls.certfiles "$TLS_ROOT" \
            2>/dev/null; }
secret() { openssl rand -hex 16; }

# 1. The bootstrap administrators of both CAs
pw=${ORG^^}_CA_PW; idca enroll -u "https://caadmin:${!pw}@localhost:$CA_PORT" \
  -M "$ORGDIR/ca-admin/msp"
pw=${ORG^^}_TLSCA_PW; tlsca enroll -u "https://caadmin:${!pw}@localhost:$TLS_PORT" \
  -M "$ORGDIR/tlsca-admin/msp"

# 2. The organization's MSP: its CAs, and which OU marks which role
mkdir -p "$ORGDIR/msp/cacerts" "$ORGDIR/msp/tlscacerts"
cp "$CA_ROOT" "$ORGDIR/msp/cacerts/$CACERT"
cp "$TLS_ROOT" "$ORGDIR/msp/tlscacerts/tlsca.pem"
{
  echo 'NodeOUs:'; echo '  Enable: true'
  for role in client peer admin orderer; do
    echo "  ${role^}OUIdentifier:"
    echo "    Certificate: cacerts/$CACERT"
    echo "    OrganizationalUnitIdentifier: $role"
  done
} > "$ORGDIR/msp/config.yaml"

tls_pair() {  # tls_pair NAME TYPE FILE HOSTS: a TLS key pair from the TLS CA
  local name=$1 type=$2 file=$3 hosts=$4 dir=$ORGDIR/$1 s
  s=$(secret)
  tlsca register -M "$ORGDIR/tlsca-admin/msp" -u "https://localhost:$TLS_PORT" \
    --id.name "$name" --id.secret "$s" --id.type "$type" >/dev/null
  tlsca enroll -u "https://$name:$s@localhost:$TLS_PORT" -M "$dir/tls-msp" \
    --enrollment.profile tls --csr.hosts "$hosts"
  mkdir -p "$dir/tls"
  cp "$dir"/tls-msp/signcerts/*.pem "$dir/tls/$file.crt"
  cp "$dir"/tls-msp/keystore/*_sk "$dir/tls/$file.key"
  cp "$TLS_ROOT" "$dir/tls/ca.crt"
  rm -rf "$dir/tls-msp"
}
issue() {  # issue NAME TYPE [TLSFILE HOSTS]: a signing identity, and a TLS pair
  local name=$1 type=$2 s
  s=$(secret)
  idca register -M "$ORGDIR/ca-admin/msp" -u "https://localhost:$CA_PORT" \
    --id.name "$name" --id.secret "$s" --id.type "$type" >/dev/null
  idca enroll -u "https://$name:$s@localhost:$CA_PORT" -M "$ORGDIR/$name/msp"
  cp "$ORGDIR/msp/config.yaml" "$ORGDIR/$name/msp/config.yaml"
  if [ $# -eq 4 ]; then tls_pair "$name" "$type" "$3" "$4"; fi
}

# 3. Nodes, administrator, a user and the chaincode server
issue peer0 peer server "peer0.$DOMAIN,localhost"
if [ "$ORDERER_NODE" != false ]; then
  issue orderer0 orderer server "orderer0.$DOMAIN,localhost"
fi
issue admin admin client localhost         # TLS client certificate: osnadmin
issue user1 client
# further users named in the network file, with certificate attributes
while IFS='|' read -r name attrs; do
  [ -n "$name" ] || continue
  s=$(secret)
  idca register -M "$ORGDIR/ca-admin/msp" -u "https://localhost:$CA_PORT" \
    --id.name "$name" --id.secret "$s" --id.type client \
    ${attrs:+--id.attrs "$attrs"} >/dev/null
  idca enroll -u "https://$name:$s@localhost:$CA_PORT" -M "$ORGDIR/$name/msp"
  cp "$ORGDIR/msp/config.yaml" "$ORGDIR/$name/msp/config.yaml"
done < <(jq -r --arg o "$ORG" '.orgs[] | select(.name == $o) | .users[]? |
  "\(.name)|\(.attrs // "")"' "$NETFILE")
tls_pair "$CC" client server "$CC.$DOMAIN,localhost"
echo "$MSP: $(ls "$ORGDIR" | grep -v -E '^(ca|tlsca|msp)$' | tr '\n' ' ')"
