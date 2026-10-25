# Source from fabric-samples/test-network to act as an identity of Org1 (ExportBank)
# or Org2 (ImportBank):
#   source ~/enterprise-blockchain/chapter-03/scripts/env.sh org2            # Org2 admin
#   source ~/enterprise-blockchain/chapter-03/scripts/env.sh org2 lcofficer  # LC officer
# It also defines lc_submit and lc_query for the lc chaincode on mychannel.
_org=${1:-org1}
_user=${2:-Admin}
case "$_org" in
  org1) export CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ADDRESS=localhost:7051 ;;
  org2) export CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_ADDRESS=localhost:9051 ;;
  *) echo "usage: source env.sh org1|org2 [user]"; return 1 ;;
esac
_peers=${PWD}/organizations/peerOrganizations
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export FABRIC_LOGGING_SPEC=INFO:grpc=error
export CORE_PEER_TLS_ENABLED=true
_tlsca=$_peers/$_org.example.com/tlsca
export CORE_PEER_TLS_ROOTCERT_FILE=$_tlsca/tlsca.$_org.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=$_peers/$_org.example.com/users/$_user@$_org.example.com/msp
_orderers=${PWD}/organizations/ordererOrganizations/example.com
export ORDERER_CA=$_orderers/tlsca/tlsca.example.com-cert.pem
export ORG1_TLS=$_peers/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
export ORG2_TLS=$_peers/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem

# lc_args FUNCTION ARG...: the JSON the peer CLI expects, built safely with jq
lc_args() {
  local fn=$1; shift
  jq -cn --arg fn "$fn" '{function: $fn, Args: $ARGS.positional}' --args "$@"
}

# lc_submit FUNCTION ARG...: endorse on both peers, order, and wait for the commit
lc_submit() {
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" -C mychannel -n lc \
    --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_TLS" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_TLS" \
    -c "$(lc_args "$@")" --waitForEvent
}

# lc_query FUNCTION ARG...: evaluate on this identity's own peer; nothing is committed
lc_query() {
  peer chaincode query -C mychannel -n lc -c "$(lc_args "$@")"
}
