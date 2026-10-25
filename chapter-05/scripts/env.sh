#!/usr/bin/env bash
#
# Sourced by every Chapter 5 script: paths, the Compose command and per-organization
# settings. Override FABRIC_SAMPLES if fabric-samples is not in your home folder.
CH5=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FABRIC_SAMPLES=${FABRIC_SAMPLES:-$HOME/fabric-samples}   # bin/, config/core.yaml
export PATH=$FABRIC_SAMPLES/bin:$PATH FABRIC_CFG_PATH=$FABRIC_SAMPLES/config
export FABRIC_LOGGING_SPEC=${FABRIC_LOGGING_SPEC:-INFO:grpc=error}
CHANNEL=lcchannel
DC=${DC:-docker compose}     # the book's capture harness puts a process runner here
COMPOSE="$DC --env-file $CH5/.secrets/ca.env -f $CH5/compose/compose-ca.yaml
  -f $CH5/compose/compose-net.yaml -f $CH5/compose/compose-monitoring.yaml"

org() {  # org NAME: set MSP, BASE port, DOMAIN and ORGDIR for one organization
  case $1 in
    exportbank)   MSP=ExportBankMSP;   BASE=7000 ;;
    importbank)   MSP=ImportBankMSP;   BASE=8000 ;;
    customs)      MSP=CustomsMSP;      BASE=9000 ;;
    shippingline) MSP=ShippingLineMSP; BASE=10000 ;;
    *) echo "unknown organization: $1" >&2; return 1 ;;
  esac
  ORG=$1 DOMAIN=$1.example.com ORGDIR=$CH5/organizations/$1
}

use() {  # use ORG [IDENTITY] [PEER]: act as IDENTITY of ORG through a peer
  org "$1" || return 1
  local who=${2:-admin} peer=${3:-peer0} port
  port=$((BASE + 51)); [ "$peer" = peer1 ] && port=$((BASE + 61))
  export CORE_PEER_LOCALMSPID=$MSP CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_MSPCONFIGPATH=$ORGDIR/$who/msp
  export CORE_PEER_TLS_ROOTCERT_FILE=$ORGDIR/msp/tlscacerts/tlsca.pem
  export CORE_PEER_ADDRESS=localhost:$port
  ORDERER=localhost:$((BASE + 50))                # this organization's own orderer
  ORDERER_CA=$ORGDIR/msp/tlscacerts/tlsca.pem
}

lc_args() {  # lc_args FUNCTION ARG...: the JSON the peer CLI expects, built with jq
  local fn=$1; shift
  jq -cn --arg fn "$fn" '{function: $fn, Args: $ARGS.positional}' --args "$@"
}

lc_submit() {  # lc_submit FUNCTION ARG...: endorse on both banks' peers and commit
  local peers=() o
  for o in exportbank:7051 importbank:8051; do
    peers+=(--peerAddresses "localhost:${o#*:}" --tlsRootCertFiles
            "$CH5/organizations/${o%:*}/msp/tlscacerts/tlsca.pem")
  done
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n lc "${peers[@]}" -c "$(lc_args "$@")" --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .*' | head -1
}

lc_query() {  # lc_query FUNCTION ARG...: evaluate on the current identity's peer
  peer chaincode query -C "$CHANNEL" -n lc -c "$(lc_args "$@")" 2>&1 |
    grep -v InitCmdFactory
}
