# Sourced by the Lab 3 scripts: the network generator's settings, the service's
# folders and a helper that calls the API as a given user.
export NETFILE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/network.json
source "$(dirname "${BASH_SOURCE[0]}")/../../network/lib/common.sh"
SVC=$LAB/service
URL=http://127.0.0.1:${PORT:-3000}

api() {  # api USER METHOD PATH [JSON]: prints the HTTP status, then the body
  local key; key=$(grep "^${1^^}=" "$SVC/.secrets/api-keys.env" | cut -d= -f2)
  curl -s -X "$2" "$URL$3" -H "authorization: Bearer $key" \
    -H 'content-type: application/json' ${4:+-d "$4"} -w ' %{http_code}' |
    sed -E 's/^(.*) ([0-9]{3})$/\2 \1/'
}

service_start() {  # start the service in the background and wait for the API
  (cd "$SVC" && exec node --disable-warning=ExperimentalWarning dist/main.js \
    >> data/service.log 2>&1) &
  echo $! > "$SVC/data/service.pid"
  wait_for 30 curl -sf "$URL/"
}

service_stop() {
  kill "$(cat "$SVC/data/service.pid")" 2>/dev/null || true
  sleep 1; rm -f "$SVC/data/service.pid"
}

cli_submit() {  # cli_submit ORG FUNCTION ARG...: outside the service, with the peer
                # CLI as ORG's user1, endorsed by the MRO's and the airline's peers
  local who=$1; shift
  local peers; mapfile -t peers < <(peer_args mro airline)
  use "$who" user1
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" -c "$(cc_args "$@")" --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .*' | head -1
}
