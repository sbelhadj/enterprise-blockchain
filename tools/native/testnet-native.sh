#!/usr/bin/env bash
#
# Author's capture harness, not a reader step.
#
# Runs fabric-samples' test-network nodes (one Raft orderer, peer0.org1, peer0.org2) as local
# processes instead of Docker containers, with the same host names, ports, environment and
# cryptogen material as compose/compose-test-net.yaml. Everything the reader types after
# "./network.sh up" (createChannel, deployCC, peer CLI calls) then runs unchanged against it.
#
# Differences from Docker, and why they do not show in captured CLI output:
#   - Chaincode is built and launched by the Node external builder from test-network-nano-bash
#     instead of a fabric-nodeenv container. The peer CLI prints the same install response.
#   - Host names resolve to 127.0.0.1 through /etc/hosts.
#
# Usage (from fabric-samples/test-network):
#   testnet-native.sh up      generate crypto with cryptogen as network.sh does, start the three nodes
#   testnet-native.sh up -ca  start the three Fabric CA servers of compose-ca.yaml as processes and
#                             enroll every identity with registerEnroll.sh, as ./network.sh up -ca does
#   testnet-native.sh up -bft four ordering nodes, as ./network.sh up -bft (compose-bft-test-net.yaml)
#   testnet-native.sh stop|start|logs NODE   stop, restart or read one node (failure drills)
#   testnet-native.sh down    stop the nodes and delete generated material and data
set -euo pipefail

TN=${TN:-$PWD}
SAMPLES=$(cd "$TN/.." && pwd)
# Node data lives in the companion repository's work/ folder (ignored by Git), not in fabric-samples
DATA=${NATIVE_DATA:-$(cd "$(dirname "$0")/../.." && pwd)/work/native}
export PATH=$SAMPLES/bin:$PATH
# The authoring machine reaches the internet through an HTTPS proxy. gRPC honors it, so the
# test-network host names must bypass it or node-to-node traffic goes to the proxy.
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1},.example.com" no_proxy="${no_proxy:-localhost,127.0.0.1},.example.com"

stop_nodes() {
  for f in "$DATA"/*.pid; do
    [ -f "$f" ] || continue
    kill "$(cat "$f")" 2>/dev/null || true
    rm -f "$f"
  done
  # chaincode processes started by the external builder
  pkill -f '^node .*fabric-chaincode-node start' 2>/dev/null || true
  sleep 1
}

hosts() {
  grep -q 'peer0.org1.example.com' /etc/hosts ||
    echo '127.0.0.1 orderer.example.com peer0.org1.example.com peer0.org2.example.com' >> /etc/hosts
  grep -q 'orderer2.example.com' /etc/hosts ||
    echo '127.0.0.1 orderer2.example.com orderer3.example.com orderer4.example.com' >> /etc/hosts
}

peercfg() {
  mkdir -p "$DATA/peercfg"
  python3 - "$TN/compose/docker/peercfg/core.yaml" "$DATA/peercfg/core.yaml" \
    "$SAMPLES/test-network-nano-bash/external_builders/node" "$SAMPLES/builders/ccaas" <<'PY'
import sys
src, dst, node, ccaas = sys.argv[1:]
t = open(src).read()
old = t[t.index('    externalBuilders:'):t.index('    # The maximum duration to wait for the chaincode build')]
new = ('    externalBuilders:\n'
       '       - name: node\n'
       '         path: %s\n'
       '         propagateEnvironment:\n'
       '           - HOME\n'
       '       - name: ccaas_builder\n'
       '         path: %s\n'
       '         propagateEnvironment:\n'
       '           - CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG\n\n' % (node, ccaas))
t = t.replace(old, new).replace('endpoint: unix:///var/run/docker.sock', "endpoint: ''")
open(dst, 'w').write(t)
PY
}

node_name() { echo "$1" | sed -e 's/\.example\.com$//' -e 's/^peer0\.\(org[0-9]\)$/peer0\1/'; }

# launch NAME: run the node's launcher script (written once by start_orderer or start_peer), so a
# node stopped for a failure drill restarts with exactly the same environment and data.
launch() {
  setsid bash "$DATA/$1.sh" >> "$DATA/$1.log" 2>&1 &
  echo $! > "$DATA/$1.pid"
}

start_orderer() { # name listen-port admin-port ops-port, as in compose-test-net / compose-bft-test-net
  local name=$1 port=$2 admin=$3 ops=$4
  local O=$TN/organizations/ordererOrganizations/example.com/orderers/$name.example.com
  mkdir -p "$DATA/$name"
  cat > "$DATA/$name.sh" <<LAUNCH
exec env FABRIC_CFG_PATH=$SAMPLES/config FABRIC_LOGGING_SPEC=INFO \\
  ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 ORDERER_GENERAL_LISTENPORT=$port \\
  ORDERER_GENERAL_LOCALMSPID=OrdererMSP ORDERER_GENERAL_LOCALMSPDIR=$O/msp \\
  ORDERER_GENERAL_TLS_ENABLED=true ORDERER_GENERAL_TLS_PRIVATEKEY=$O/tls/server.key \\
  ORDERER_GENERAL_TLS_CERTIFICATE=$O/tls/server.crt "ORDERER_GENERAL_TLS_ROOTCAS=[$O/tls/ca.crt]" \\
  ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=$O/tls/server.crt \\
  ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=$O/tls/server.key "ORDERER_GENERAL_CLUSTER_ROOTCAS=[$O/tls/ca.crt]" \\
  ORDERER_GENERAL_BOOTSTRAPMETHOD=none ORDERER_CHANNELPARTICIPATION_ENABLED=true \\
  ORDERER_ADMIN_TLS_ENABLED=true ORDERER_ADMIN_TLS_CERTIFICATE=$O/tls/server.crt \\
  ORDERER_ADMIN_TLS_PRIVATEKEY=$O/tls/server.key "ORDERER_ADMIN_TLS_ROOTCAS=[$O/tls/ca.crt]" \\
  "ORDERER_ADMIN_TLS_CLIENTROOTCAS=[$O/tls/ca.crt]" ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:$admin \\
  ORDERER_OPERATIONS_LISTENADDRESS=$name.example.com:$ops ORDERER_METRICS_PROVIDER=prometheus \\
  ORDERER_FILELEDGER_LOCATION=$DATA/$name \\
  ORDERER_CONSENSUS_WALDIR=$DATA/$name/etcdraft/wal ORDERER_CONSENSUS_SNAPDIR=$DATA/$name/etcdraft/snapshot \\
  orderer
LAUNCH
  launch "$name"
}

start_peer() { # org port ops
  local org=$1 port=$2 ops=$3
  local P=$TN/organizations/peerOrganizations/org$org.example.com/peers/peer0.org$org.example.com
  local H=peer0.org$org.example.com
  local name=peer0org$org
  # the node builder writes chaincode logs to ./logs relative to the peer's working directory
  mkdir -p "$DATA/$name/logs"
  # chaincode listens on port+11 (7062, 9062): 7052 belongs to orderer2 in the BFT network
  cat > "$DATA/$name.sh" <<LAUNCH
cd $DATA/$name
exec env FABRIC_CFG_PATH=$DATA/peercfg FABRIC_LOGGING_SPEC=INFO CORE_PEER_TLS_ENABLED=true \\
  CORE_PEER_PROFILE_ENABLED=false CORE_PEER_TLS_CERT_FILE=$P/tls/server.crt \\
  CORE_PEER_TLS_KEY_FILE=$P/tls/server.key CORE_PEER_TLS_ROOTCERT_FILE=$P/tls/ca.crt \\
  CORE_PEER_ID=$H CORE_PEER_ADDRESS=$H:$port CORE_PEER_LISTENADDRESS=0.0.0.0:$port \\
  CORE_PEER_CHAINCODEADDRESS=$H:$((port+11)) CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$((port+11)) \\
  CORE_PEER_GOSSIP_BOOTSTRAP=$H:$port CORE_PEER_GOSSIP_EXTERNALENDPOINT=$H:$port \\
  CORE_PEER_LOCALMSPID=Org${org}MSP CORE_PEER_MSPCONFIGPATH=$P/msp \\
  CORE_OPERATIONS_LISTENADDRESS=$H:$ops CORE_METRICS_PROVIDER=prometheus \\
  'CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG={"peername":"peer0org$org"}' CORE_CHAINCODE_EXECUTETIMEOUT=300s \\
  CORE_PEER_FILESYSTEMPATH=$DATA/$name CORE_LEDGER_SNAPSHOTS_ROOTDIR=$DATA/$name/snapshots \\
  CORE_VM_ENDPOINT= \\
  peer node start
LAUNCH
  launch "$name"
}

start_cas() {
  # name:port:operations-port:CA name, as in compose/compose-ca.yaml
  for spec in org1:7054:17054:ca-org1 org2:8054:18054:ca-org2 ordererOrg:9054:19054:ca-orderer; do
    IFS=: read -r dir port ops name <<< "$spec"
    env FABRIC_CA_HOME=$TN/organizations/fabric-ca/$dir FABRIC_CA_SERVER_CA_NAME=$name \
      FABRIC_CA_SERVER_TLS_ENABLED=true FABRIC_CA_SERVER_PORT=$port \
      FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=127.0.0.1:$ops \
      setsid fabric-ca-server start -b admin:adminpw > "$DATA/ca-$dir.log" 2>&1 &
    echo $! > "$DATA/ca-$dir.pid"
  done
  for dir in org1 org2 ordererOrg; do
    for i in $(seq 1 30); do [ -f "$TN/organizations/fabric-ca/$dir/tls-cert.pem" ] && break; sleep 1; done
  done
  sleep 2
  # the same functions network.sh calls in createOrgs() for -ca
  ( cd "$TN" && . scripts/utils.sh && . organizations/fabric-ca/registerEnroll.sh &&
    createOrg1 && createOrg2 && createOrderer ) > "$DATA/enroll.log" 2>&1
  ./organizations/ccp-generate.sh > /dev/null
}

clean_ca_files() {
  for dir in org1 org2 ordererOrg; do
    ( cd "$TN/organizations/fabric-ca/$dir" &&
      rm -rf msp tls-cert.pem ca-cert.pem IssuerPublicKey IssuerRevocationPublicKey fabric-ca-server.db )
  done
}

wait_healthy() {
  local eps="orderer.example.com:9443 peer0.org1.example.com:9444 peer0.org2.example.com:9445"
  [ -f "$DATA/orderer2.sh" ] && eps="$eps orderer2.example.com:9446 orderer3.example.com:9447 orderer4.example.com:9448"
  for ep in $eps; do
    for i in $(seq 1 30); do
      curl -s "http://$ep/healthz" | grep -q '"status":"OK"' && break
      sleep 1
      [ "$i" = 30 ] && { echo "node at $ep not healthy"; exit 1; }
    done
  done
  echo "native test network up: $(ls "$DATA"/*.pid | xargs -n1 basename | sed 's/.pid//' | tr '\n' ' ')"
}

case "${1:-}" in
  up)
    stop_nodes; rm -rf "$DATA"; mkdir -p "$DATA"; hosts
    if [ "${2:-}" = "-ca" ] && [ ! -d organizations/peerOrganizations ]; then
      clean_ca_files; start_cas
    fi
    # the same cryptogen calls network.sh makes in createOrgs()
    if [ ! -d organizations/peerOrganizations ]; then
      for f in org1 org2 orderer; do
        cryptogen generate --config=./organizations/cryptogen/crypto-config-$f.yaml --output=organizations > /dev/null
      done
      ./organizations/ccp-generate.sh > /dev/null
    fi
    peercfg
    start_orderer orderer 7050 7053 9443
    if [ "${2:-}" = "-bft" ]; then
      # the four ordering nodes of compose-bft-test-net.yaml
      start_orderer orderer2 7052 7055 9446
      start_orderer orderer3 7056 7057 9447
      start_orderer orderer4 7058 7059 9448
    fi
    start_peer 1 7051 9444; start_peer 2 9051 9445; wait_healthy ;;
  # Failure drills. NODE may be given as the Compose container name (orderer2.example.com,
  # peer0.org1.example.com) or the short name (orderer2, peer0org1); output mimics docker.
  stop)
    n=$(node_name "$2"); kill "$(cat "$DATA/$n.pid")" && rm -f "$DATA/$n.pid"; echo "$2" ;;
  start)
    n=$(node_name "$2"); launch "$n"; echo "$2" ;;
  logs)
    cat "$DATA/$(node_name "$2").log" ;;
  down)
    stop_nodes
    clean_ca_files
    rm -rf "$DATA" organizations/peerOrganizations organizations/ordererOrganizations channel-artifacts log.txt ./*.tar.gz ;;
  *) echo "usage: $0 up [-ca|-bft] | stop NODE | start NODE | logs NODE | down"; exit 2 ;;
esac
