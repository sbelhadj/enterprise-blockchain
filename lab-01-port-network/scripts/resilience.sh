#!/usr/bin/env bash
#
# Listing L1.9: Part D resilience. Stop the Raft leader, submit again, bring the
# orderer back and check that it caught up.
set -euo pipefail
source "$(dirname "$0")/env.sh"
leader=""
for o in $FOUNDERS; do
  org "$o"
  m=$(curl -s "http://localhost:$((BASE + 444))/metrics")
  grep -q '^consensus_etcdraft_is_leader{.*} 1' <<< "$m" && leader=$o
done
echo "== stop the leader, orderer0.$leader.example.com"
$COMPOSE stop "orderer0-$leader" 2>&1 | grep Error || true
sleep 8                                 # election timeout and a new term
raft
via=$(echo $FOUNDERS | tr ' ' '\n' | grep -v -x "$leader" | head -1)
echo "== a shipment while it is down, sent to orderer0.$via.example.com"
echo "   $(VIA=$via submit shippingline CreateShipment SH-0002 MSCU7654321 \
  'MSC Aurora' CNSHA 'Carthage Foods')"
echo "== start it again"
$COMPOSE start "orderer0-$leader" 2>&1 | grep Error || true
sleep 8
raft
org "$leader"
echo "orderer0.$leader.example.com height: $(osnadmin channel list \
  --channelID "$CHANNEL" -o "localhost:$((BASE + 53))" \
  --ca-file "$ORGDIR/msp/tlscacerts/tlsca.pem" \
  --client-cert "$ORGDIR/admin/tls/client.crt" \
  --client-key "$ORGDIR/admin/tls/client.key" | grep -o '"height": [0-9]*')"
heights
