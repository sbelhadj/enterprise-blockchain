# Sourced by every network generator script. Reads the network file named by
# NETFILE and defines paths, the Compose command and per-organization settings.
# Everything generated goes to build/ next to the network file (ignored by Git).
NET=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NETFILE=$(cd "$(dirname "$NETFILE")" && pwd)/$(basename "$NETFILE")
LAB=$(dirname "$NETFILE") BUILD=$(dirname "$NETFILE")/build
FABRIC_SAMPLES=${FABRIC_SAMPLES:-$HOME/fabric-samples}   # bin/ and config/core.yaml
export PATH=$FABRIC_SAMPLES/bin:$PATH FABRIC_CFG_PATH=$FABRIC_SAMPLES/config
export FABRIC_LOGGING_SPEC=${FABRIC_LOGGING_SPEC:-INFO:grpc=error}

cfg() { jq -r "$1" "$NETFILE"; }
PROJECT=$(cfg .project) CHANNEL=$(cfg .channel)
STATEDB=${STATEDB:-$(cfg '.statedb // "goleveldb"')}  # CouchDB or goleveldb
CC=$(cfg .chaincode.name) CC_VERSION=$(cfg .chaincode.version)
CC_PATH=$LAB/$(cfg .chaincode.path) CC_LABEL=${CC}_$(cfg .chaincode.version)
FOUNDERS=$(cfg '[.orgs[] | select(.joins != "later") | .name] | join(" ")')
ALL_ORGS=$(cfg '[.orgs[].name] | join(" ")')
DC=${DC:-docker compose}     # the book's capture harness puts a process runner here
VOLRM=${VOLRM:-docker volume rm}               # and its own volume removal here
COMPOSE="$DC --env-file $BUILD/.secrets/network.env -f $BUILD/compose-ca.yaml
  -f $BUILD/compose-net.yaml"

org() {  # org NAME: MSP, BASE port, ORDERER_NODE, DOMAIN and ORGDIR of one org
  local j
  j=$(jq -c --arg n "$1" '.orgs[] | select(.name == $n)' "$NETFILE")
  [ -n "$j" ] || { echo "unknown organization: $1" >&2; return 1; }
  ORG=$1 DOMAIN=$1.example.com ORGDIR=$BUILD/organizations/$1
  MSP=$(jq -r .msp <<< "$j") BASE=$(jq -r .base <<< "$j")
  ORDERER_NODE=$(jq -r '.orderer // false' <<< "$j")
}

use() {  # use ORG [IDENTITY]: act as IDENTITY (default admin) of ORG on its peer0
  org "$1" || return 1
  export CORE_PEER_LOCALMSPID=$MSP CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_MSPCONFIGPATH=$ORGDIR/${2:-admin}/msp
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORGDIR/msp/tlscacerts/tlsca.pem
  export CORE_PEER_ADDRESS=localhost:$((BASE + 51))
  if [ "$ORDERER_NODE" = true ]; then           # this organization's own orderer
    ORDERER=localhost:$((BASE + 50)) ORDERER_CA=$ORGDIR/msp/tlscacerts/tlsca.pem
  else                                          # no orderer: use a founder's
    local first base
    first=$(cfg '[.orgs[] | select(.orderer == true)][0].name')
    base=$(cfg "[.orgs[] | select(.orderer == true)][0].base")
    ORDERER=localhost:$((base + 50))
    ORDERER_CA=$BUILD/organizations/$first/msp/tlscacerts/tlsca.pem
  fi
}

peer_args() {  # peer_args ORG...: --peerAddresses and TLS roots for those peers
  local o
  for o in "$@"; do
    org "$o"
    printf -- '--peerAddresses\nlocalhost:%s\n--tlsRootCertFiles\n%s\n' \
      $((BASE + 51)) "$ORGDIR/msp/tlscacerts/tlsca.pem"
  done
}

cc_args() {  # cc_args FUNCTION ARG...: the JSON the peer CLI expects
  local fn=$1; shift
  jq -cn --arg fn "$fn" '{function: $fn, Args: $ARGS.positional}' --args "$@"
}

wait_for() {  # wait_for SECONDS COMMAND...: retry until the command succeeds
  local n=$1 i; shift
  for i in $(seq "$n"); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done
  return 1
}
