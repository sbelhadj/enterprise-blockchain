#!/usr/bin/env bash
#
# Captures the failure messages of Table 5.5 on the running Chapter 5 network (after
# add-customs.sh). Author's script, not a reader step; each case restores what it broke.
set -uo pipefail
cd "$(dirname "$0")/../../chapter-05"
source scripts/env.sh
first() { grep -m1 -o -E "${1:-Error: .*}" | cut -c1-240; }
case_() { echo; echo "== $*"; }

case_ "1. ImportBank's admin calls the channel participation API of ExportBank's orderer"
org importbank; A=$ORGDIR/admin/tls
osnadmin channel list -o localhost:7053 --ca-file "$CH5/organizations/exportbank/msp/tlscacerts/tlsca.pem" \
  --client-cert "$A/client.crt" --client-key "$A/client.key" 2>&1 | first '.*(tls|certificate|Error).*'

case_ "2. The client trusts the wrong TLS CA for the orderer"
use exportbank user1
peer chaincode invoke -o localhost:7050 --tls --cafile "$CH5/organizations/importbank/msp/tlscacerts/tlsca.pem" \
  -C "$CHANNEL" -n lc -c "$(lc_args ReadLC LC-2026-101)" 2>&1 | first

case_ "3. The MSP ID does not match the certificate"
use exportbank user1; export CORE_PEER_LOCALMSPID=ImportBankMSP
lc_query ReadLC LC-2026-101 2>&1 | first 'access denied: .*malformed'

case_ "4. A client identity tries to join a peer to the channel"
use exportbank user1
peer channel join -b "$CH5/channel-artifacts/$CHANNEL.block" 2>&1 |
  grep -o -E 'access denied for \[JoinChain\]\[lcchannel\]|The identity does not contain OU \[ADMIN\]'

case_ "5. An administrator joins a peer that is already on the channel"
use exportbank
peer channel join -b "$CH5/channel-artifacts/$CHANNEL.block" 2>&1 |
  first 'ledger \[.*\] already exists with state \[ACTIVE\]'

case_ "6. Enrollment with a wrong secret"
org importbank
fabric-ca-client enroll -u "https://user1:wrong-secret@localhost:8054" --caname ca-importbank \
  --tls.certfiles "$ORGDIR/ca/ca-cert.pem" -M "$CH5/channel-artifacts/badenroll" 2>&1 | first

case_ "7. A definition committed before enough organizations approved it"
use exportbank
peer lifecycle chaincode commit -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" -n lc \
  -v 1.2 --sequence 2 --peerAddresses localhost:7051 --tlsRootCertFiles "$ORDERER_CA" 2>&1 |
  first 'chaincode definition not agreed to by this org.*'

case_ "8. ExportBank's chaincode server is down"
$COMPOSE stop lc-exportbank >/dev/null 2>&1
use exportbank user1
lc_query ReadLC LC-2026-101 2>&1 | grep -o -E \
  'could not launch chaincode lc_1.1|error creating grpc connection to [^:]*:[0-9]+|connect: connection refused'
$COMPOSE start lc-exportbank >/dev/null 2>&1

case_ "9. Two of three orderers are down"
$COMPOSE stop orderer0-importbank orderer0-customs >/dev/null 2>&1
sleep 8
use exportbank user1
peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" -n lc \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORDERER_CA" \
  -c "$(lc_args LCExists LC-2026-101)" 2>&1 | first 'got unexpected status: [A-Z_]+ -- no Raft leader'
$COMPOSE start orderer0-importbank orderer0-customs >/dev/null 2>&1


case_ "10. ExportBank's chaincode server runs with a package ID the peer does not expect"
$COMPOSE stop lc-exportbank >/dev/null 2>&1
LC_PACKAGE_ID_EXPORTBANK=lc_1.0:0000 $COMPOSE up -d lc-exportbank >/dev/null 2>&1
sleep 3
use exportbank user1
timeout 20 peer chaincode query -C "$CHANNEL" -n lc -c "$(lc_args ReadLC LC-2026-101)" \
  >/dev/null 2>&1; echo "client: no answer after 20 s (exit code $?)"
$COMPOSE logs peer0-exportbank 2>&1 | sed 's/\x1b\[[0-9;]*m//g' |
  first 'failed to start lc_1.0:0000 -- .*' | sed 's/^/peer log: /'
$COMPOSE stop lc-exportbank >/dev/null 2>&1
id=$(peer lifecycle chaincode calculatepackageid "$CH5/packages/exportbank/lc_1.1.tgz")
LC_PACKAGE_ID_EXPORTBANK=$id $COMPOSE up -d lc-exportbank >/dev/null 2>&1
