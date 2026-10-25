# Sourced by the Lab 4 scripts: the network generator's settings for network.json,
# and helpers for transactions, configuration updates and the ordering service.
export NETFILE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/network.json
source "$(dirname "${BASH_SOURCE[0]}")/../../network/lib/common.sh"
W=$BUILD/drill; mkdir -p "$W"

issue_lc() {  # issue_lc ID: ImportBank's LC officer issues a letter of credit,
              # endorsed by the peers of $ENDORSERS (organization names)
  local peers
  mapfile -t peers < <(peer_args ${ENDORSERS:-exportbank importbank customs})
  use importbank lcofficer
  if [ -n "${VIA:-}" ]; then                 # through another org's orderer
    org "$VIA"; ORDERER=localhost:$((BASE + 50))
    ORDERER_CA=$ORGDIR/msp/tlscacerts/tlsca.pem
  fi
  peer chaincode invoke -o "$ORDERER" --tls --cafile "$ORDERER_CA" -C "$CHANNEL" \
    -n "$CC" "${peers[@]}" -c "$(cc_args IssueLC "$1" 'Tunis Olive Imports' \
    'Sfax Olive Oil Co' ExportBankMSP 1250000 USD 2027-06-30 'Olive oil, 20 t')" \
    --waitForEvent 2>&1 |
    grep -o -E 'committed with status \([A-Z_]+\)|Error: .{0,120}' | head -1 |
    sed 's/^committed with status/committed/'
}

traffic_start() {  # one letter of credit every 2 seconds until traffic_stop
  rm -f "$W/traffic.log"
  ( i=0; while [ ! -e "$W/traffic.stop" ]; do
      i=$((i + 1)); echo "$(issue_lc "TR-$(date +%s)-$i")" >> "$W/traffic.log"
      sleep 2
    done ) &
  TRAFFIC_PID=$!
}
traffic_stop() {
  touch "$W/traffic.stop"; wait "$TRAFFIC_PID" 2>/dev/null || true
  rm "$W/traffic.stop"
  echo "traffic during the change: $(wc -l < "$W/traffic.log") transactions," \
    "$(grep -c 'VALID)' "$W/traffic.log" || true) committed VALID"
  grep -v 'VALID)' "$W/traffic.log" | sort | uniq -c | sed 's/^/  /' || true
}

osn() {  # osn ORG ARGS...: osnadmin channel ARGS against ORG's own orderer
  local o=$1; shift
  org "$o"
  osnadmin channel "$@" -o "localhost:$((BASE + 53))" \
    --ca-file "$ORGDIR/msp/tlscacerts/tlsca.pem" \
    --client-cert "$ORGDIR/admin/tls/client.crt" \
    --client-key "$ORGDIR/admin/tls/client.key"
}

fetch_config() {  # fetch_config FILE: the channel configuration as JSON
  use exportbank
  peer channel fetch config "$W/config.pb" -o "$ORDERER" --tls \
    --cafile "$ORDERER_CA" -c "$CHANNEL" >/dev/null 2>&1
  configtxlator proto_decode --type common.Block --input "$W/config.pb" |
    jq '.data.data[0].payload.data.config' > "$1"
}

make_update() {  # make_update ORIGINAL.json MODIFIED.json OUT.pb: signable envelope
  local f
  for f in "$1" "$2"; do
    configtxlator proto_encode --type common.Config --input "$f" --output "$f.pb"
  done
  configtxlator compute_update --channel_id "$CHANNEL" --original "$1.pb" \
    --updated "$2.pb" | configtxlator proto_decode --type common.ConfigUpdate |
    jq --arg ch "$CHANNEL" '{payload: {header: {channel_header: {channel_id: $ch,
      type: 2}}, data: {config_update: .}}}' |
    configtxlator proto_encode --type common.Envelope --output "$3"
}

sign_and_submit() {  # sign_and_submit FILE ORG...: all but the last sign, the last
                     # signs and submits
  local f=$1 o; shift
  for o in "$@"; do
    use "$o"
    if [ "$o" != "${*: -1}" ]; then
      peer channel signconfigtx -f "$f" >/dev/null 2>&1 && echo "  $MSP signs"
    else
      echo "  $MSP signs and submits: $(peer channel update -f "$f" -c "$CHANNEL" \
        -o "$ORDERER" --tls --cafile "$ORDERER_CA" 2>&1 |
        grep -o -E 'Successfully submitted channel update|Error: .{0,160}')"
    fi
  done
}

consenters() {  # the Raft consenters in the current configuration
  fetch_config "$W/now.json"
  jq -r '.channel_group.groups.Orderer.values.ConsensusType.value.metadata
    .consenters[] | "  \(.host):\(.port)"' "$W/now.json"
}

heights() {  # every joined peer's height, and its last block hash
  local o
  for o in $ALL_ORGS; do
    use "$o"
    peer channel getinfo -c "$CHANNEL" 2>/dev/null | sed 's/^Blockchain info: //' |
      jq -r --arg o "$o" '"  peer0.\($o): height \(.height), last block " +
        (.currentBlockHash | .[0:16])' || true
  done
}
