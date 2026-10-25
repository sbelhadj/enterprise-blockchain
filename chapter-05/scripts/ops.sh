#!/usr/bin/env bash
#
# Listing 5.12: the operations endpoint of every node: health, version, a few
# metrics, a log level changed at run time, and Prometheus scraping all of them.
set -euo pipefail
source "$(dirname "$0")/env.sh"
NODES="orderer0.exportbank:7444 orderer0.importbank:8444 orderer0.customs:9444
       peer0.exportbank:7443 peer0.importbank:8443"
metric() {  # metric PORT NAME: one lcchannel metric, or - if the node has none
  curl -s "http://localhost:$1/metrics" | awk -v k="$2{channel=\"$CHANNEL\"}" \
    '$1 == k {print $2; f=1} END {if (!f) print "-"}'
}
ROW='%-21s %-7s %-8s %-7s %-12s %s\n'
printf "$ROW" node health version height raft-leader peers-known
for n in $NODES; do
  p=${n#*:}
  printf "$ROW" "${n%:*}" \
    "$(curl -s "localhost:$p/healthz" | jq -r .status)" \
    "$(curl -s "localhost:$p/version" | jq -r .Version)" \
    "$(metric "$p" ledger_blockchain_height)" \
    "$(metric "$p" consensus_etcdraft_is_leader)" \
    "$(metric "$p" gossip_membership_total_peers_known)"
done

echo "== log level of peer0.exportbank, raised for the chaincode subsystem only"
curl -s localhost:7443/logspec
curl -s -X PUT -d '{"spec":"chaincode=debug:info"}' localhost:7443/logspec
curl -s localhost:7443/logspec
curl -s -X PUT -d '{"spec":"info"}' localhost:7443/logspec       # and back
curl -s localhost:7443/logspec

echo "== Prometheus scrapes every node"
$COMPOSE up -d prometheus 2>&1 | grep -E 'Started|Error' || true
for i in $(seq 40); do        # wait for the first scrape of the six running nodes
  n=$(curl -s localhost:9090/api/v1/targets |
      jq '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null ||
      echo 0)
  [ "$n" -ge 6 ] && break; sleep 1
done
curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] |
  "\(.labels.job)  \(.labels.instance)  \(.health)"' | sort
curl -s 'localhost:9090/api/v1/query?query=ledger_blockchain_height' |
  jq -r '.data.result[] | "\(.metric.instance)  height \(.value[1])"' | sort
