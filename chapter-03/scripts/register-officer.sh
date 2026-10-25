#!/usr/bin/env bash
#
# Listing 3.14: register and enroll an LC officer at ImportBank (Org2) whose certificate
# carries lc.role=issuer. Run from fabric-samples/test-network, on a network started
# with -ca.
set -euo pipefail
ORG2=${PWD}/organizations/peerOrganizations/org2.example.com
CA_TLS=${PWD}/organizations/fabric-ca/org2/ca-cert.pem
export PATH=${PWD}/../bin:$PATH
# The CA admin that network.sh enrolled acts as the registrar
export FABRIC_CA_CLIENT_HOME=$ORG2
# A one-time enrollment secret, generated here and never stored or printed
SECRET=$(openssl rand -hex 16)

fabric-ca-client register --caname ca-org2 --tls.certfiles "$CA_TLS" \
  --id.name lcofficer --id.secret "$SECRET" --id.type client \
  --id.attrs 'lc.role=issuer:ecert' |
  sed 's/^Password: .*/Password: (not shown: the secret stays in this script)/'
fabric-ca-client enroll --caname ca-org2 --tls.certfiles "$CA_TLS" \
  -u "https://lcofficer:$SECRET@localhost:8054" \
  -M "$ORG2/users/lcofficer@org2.example.com/msp"
cp "$ORG2/msp/config.yaml" "$ORG2/users/lcofficer@org2.example.com/msp/config.yaml"

# The attribute is in the certificate, as JSON in Fabric CA's extension 1.2.3.4.5.6.7.8.1
CERT=$ORG2/users/lcofficer@org2.example.com/msp/signcerts/cert.pem
openssl x509 -in "$CERT" -noout -subject
openssl x509 -in "$CERT" -noout -text | grep -A1 '1.2.3.4.5.6.7.8.1' | tail -1 |
  sed 's/^ *//'
