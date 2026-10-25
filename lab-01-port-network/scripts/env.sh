# Sourced by the Lab 1 scripts: the network generator's settings for network.json,
# plus helpers to submit and query the shipment chaincode.
export NETFILE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/network.json
source "$(dirname "${BASH_SOURCE[0]}")/../../network/lib/common.sh"

submit() {  # submit ORG FUNCTION ARG...: as ORG's user1, endorsed by $ENDORSERS
  local who=$1; shift
  local peers
  mapfile -t peers < <(peer_args ${ENDORSERS:-$FOUNDERS})
  use "$who" user1
  if [ -n "${VIA:-}" ]; then                  # send to another org's orderer
    org "$VIA"; ORDERER=localhost:$((BASE + 50))
    ORDERER_CA=$ORGDIR/msp/tlscacerts/tlsca.pem
  fi
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" -c "$(cc_args "$@")" --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .*' | head -1 |
    sed -e 's/Error: endorsement failure during invoke. response: status:500 //' \
        -e 's/^committed with status/committed/' -e 's/^message:"\(.*\)"$/\1/'
}

query() {  # query ORG FUNCTION ARG...: evaluate on ORG's own peer as its user1
  local who=$1; shift
  use "$who" user1
  peer chaincode query -C "$CHANNEL" -n "$CC" -c "$(cc_args "$@")" 2>&1 |
    grep -v InitCmdFactory
}

heights() {  # the block height of every joined peer, on one line
  local o out=()
  for o in $ALL_ORGS; do
    use "$o"
    h=$(peer channel getinfo -c "$CHANNEL" 2>/dev/null | grep -o '"height":[0-9]*' |
        cut -d: -f2) || true
    [ -n "$h" ] && out+=("$o=$h")
  done
  echo "heights: ${out[*]}"
}

raft() {  # leader and cluster size as each orderer reports them in its metrics
  local o m
  for o in $ALL_ORGS; do
    org "$o"; [ "$ORDERER_NODE" = true ] || continue
    m=$(curl -s "http://localhost:$((BASE + 444))/metrics" || true)
    if [ -z "$m" ]; then printf '  %-34s down\n' "orderer0.$DOMAIN"; continue; fi
    printf '  %-34s leader=%s cluster=%s\n' "orderer0.$DOMAIN" \
      "$(grep '^consensus_etcdraft_is_leader{' <<< "$m" | awk '{print $2}')" \
      "$(grep '^consensus_etcdraft_cluster_size{' <<< "$m" | awk '{print $2}')"
  done
}
