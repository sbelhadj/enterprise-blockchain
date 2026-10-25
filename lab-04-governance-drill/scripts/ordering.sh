#!/usr/bin/env bash
#
# Listing L4.4: Part D. ShippingLine's orderer replaces CustomsAuthority's in the
# Raft cluster, one configuration update at a time, with a block after each.
set -euo pipefail
source "$(dirname "$0")/env.sh"
SL=orderer0.shippingline.example.com
status() {  # status ORG: what ORG's orderer says about the channel
  osn "$1" list --channelID "$CHANNEL" 2>/dev/null | sed -n '/^{/,$p' |
    jq -r '"  \(.name) on orderer0.'"$1"': \(.consensusRelation), \(.status),"
      + " height \(.height)"' || echo "  orderer0.$1: no channel"
}
echo "== consenters before"; consenters
traffic_start

echo "== 1. ShippingLineMSP joins the Orderer group, with its endpoint"
fetch_config "$W/c.json"
jq --arg ep "$SL:10050" '.channel_group.groups.Application.groups.ShippingLineMSP
  | del(.values.AnchorPeers) | .values.Endpoints = {mod_policy: "Admins",
    value: {addresses: [$ep]}, version: "0"}' "$W/c.json" > "$W/sl.json"
jq --slurpfile o "$W/sl.json" '.channel_group.groups.Orderer.groups.ShippingLineMSP
  = $o[0]' "$W/c.json" > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/u1.pb"
sign_and_submit "$W/u1.pb" exportbank importbank   # 2 of 3 orderer orgs
echo "  block after the change: $(issue_lc LD-1)"

echo "== 2. Its orderer starts and joins as a follower"
$COMPOSE up -d orderer0-shippingline 2>&1 | grep Error || true
wait_for 30 curl -sf "http://localhost:10444/healthz"
fetch_config "$W/c.json"                        # also leaves the block in config.pb
osn shippingline join --channelID "$CHANNEL" --config-block "$W/config.pb" |
  grep -o 'Status: [0-9]*' | sed 's/^/  join: /'
sleep 5; status shippingline

echo "== 3. It becomes a consenter"
org shippingline; T=$ORGDIR/orderer0/tls/server.crt
jq --arg h "$SL" --arg c "$(base64 -w0 < "$T")" \
  '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters
   += [{host: $h, port: 10050, client_tls_cert: $c, server_tls_cert: $c}]' \
  "$W/c.json" > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/u2.pb"
sign_and_submit "$W/u2.pb" exportbank importbank customs   # now 3 of 4
sleep 8; status shippingline
echo "  block after the change: $(issue_lc LD-2)"

echo "== 4. CustomsAuthority's orderer leaves the cluster"
fetch_config "$W/c.json"
jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters
   |= map(select(.host != "orderer0.customs.example.com"))' "$W/c.json" \
  > "$W/m.json"
make_update "$W/c.json" "$W/m.json" "$W/u3.pb"
sign_and_submit "$W/u3.pb" exportbank importbank shippingline
sleep 5
osn customs remove --channelID "$CHANNEL" | grep -o 'Status: [0-9]*' |
  sed 's/^/  customs removes the channel from its orderer: /'
$COMPOSE stop orderer0-customs 2>&1 | grep Error || true
echo "  block after the change: $(issue_lc LD-3)"
traffic_stop
echo "== consenters after"; consenters
