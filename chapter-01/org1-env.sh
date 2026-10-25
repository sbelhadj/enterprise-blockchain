# Source this from fabric-samples/test-network to act as the Org1 administrator:
#   source ~/enterprise-blockchain/chapter-01/org1-env.sh
# These are the variables the Fabric documentation uses for the test network.
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
# Fabric 3.1's CLI logs every gRPC connection step at INFO; keep only Fabric's own messages
export FABRIC_LOGGING_SPEC=INFO:grpc=error
