# Sourced by the Lab 2 scripts: the network generator's settings for network.json,
# plus helpers for the PharmaTrace chaincode.
export NETFILE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/network.json
source "$(dirname "${BASH_SOURCE[0]}")/../../network/lib/common.sh"

submit() {  # submit ORG FUNCTION ARG...: as ORG's user1, endorsed by the peers of
            # $ENDORSERS (organization names), with $TRANSIENT as transient data
  local who=$1; shift
  local peers t=()
  mapfile -t peers < <(peer_args ${ENDORSERS:?name the endorsing organizations})
  [ -n "${TRANSIENT:-}" ] && t=(--transient "$TRANSIENT")
  use "$who" user1
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" "${t[@]}" -c "$(cc_args "$@")" --waitForEvent 2>&1 |
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

terms() {  # terms JSON: the transient map the CLI expects, value in base64
  jq -cn --arg t "$1" '{terms: ($t | @base64)}'
}
