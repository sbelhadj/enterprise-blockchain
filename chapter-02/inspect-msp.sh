#!/usr/bin/env bash
#
# Listing 2.1: what is inside peer0.org1's MSP. Run from fabric-samples/test-network.
set -euo pipefail
P=organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com

echo "== Folders of the peer's local MSP and TLS material"
find "$P" -type f | sed "s#^$P/##" | sort

echo "== NodeOU configuration (msp/config.yaml)"
cat "$P/msp/config.yaml"

echo "== The peer's signing certificate"
openssl x509 -in "$P/msp/signcerts/peer0.org1.example.com-cert.pem" -noout \
  -subject -issuer -enddate -ext keyUsage
openssl x509 -in "$P/msp/signcerts/peer0.org1.example.com-cert.pem" -noout -text |
  grep -E 'Public Key Algorithm|ASN1 OID'

echo "== The root CA it chains to"
openssl x509 -in "$P/msp/cacerts/ca.org1.example.com-cert.pem" -noout -subject -issuer
openssl verify -CAfile "$P/msp/cacerts/ca.org1.example.com-cert.pem" \
  "$P/msp/signcerts/peer0.org1.example.com-cert.pem"

echo "== The TLS server certificate: a different CA, and the names clients may use"
openssl x509 -in "$P/tls/server.crt" -noout -subject -issuer -ext subjectAltName
