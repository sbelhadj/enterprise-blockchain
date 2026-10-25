#!/usr/bin/env bash
#
# Appendix A, Exercise 4.2: stop the Raft leader of CHANNEL and build the
# timeline of the election from the remaining nodes' logs. Run from
# fabric-samples/test-network: raft-election.sh raftchannel|raft20
set -uo pipefail
CH=${1:?usage: raft-election.sh CHANNEL}
HERE=$(cd "$(dirname "$0")" && pwd)
NODE_CTL=${NODE_CTL:-docker}
export PATH=${PWD}/../bin:$PATH
declare -A PORT=([orderer]=7050 [orderer2]=7052 [orderer3]=7056)
declare -A OPS=([orderer]=9443 [orderer2]=9446 [orderer3]=9447)
metric() {
  curl -s --max-time 2 "http://localhost:${OPS[$1]}/metrics" |
    awk -v k="$2{channel=\"$CH\"}" '$1 == k {print $2}'
}
leader() {
  for n in orderer orderer2 orderer3; do
    [ "$(metric $n consensus_etcdraft_is_leader)" = 1 ] && echo $n
  done
  return 0
}
ms() { date +%H:%M:%S.%3N; }
L=$(leader); C=$(printf '%s\n' orderer orderer2 orderer3 | grep -vx "$L" | head -1)
echo "$CH: leader $L, ElectionTick $(jq -r '.data.data[0].payload.data.config
  .channel_group.groups.Orderer.values.ConsensusType.value.metadata.options
  .election_tick' < <(configtxlator proto_decode --type common.Block \
  --input "$(cd "$HERE/../.." && pwd)/work/chapter-04/$CH.block"))"
T0=$(ms); s0=$(date +%s.%N)
$NODE_CTL stop "$L.example.com" >/dev/null
echo "$T0 leader $L stopped (last heartbeat at most 500 ms earlier)"
until N=$(leader) && [ -n "$N" ]; do sleep 0.1; done
echo "$(ms) metrics report $N as leader ($(printf '%.1f' \
  "$(echo "$(date +%s.%N) - $s0" | bc)") s)"
for n in orderer orderer2 orderer3; do
  [ "$n" = "$L" ] && continue
  $NODE_CTL logs "$n.example.com" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' |
    grep "channel=$CH " |
    grep -E 'new election|became (pre-)?candidate|became leader|leader changed' |
    awk -v t="$T0" -v n="$n" '$2 > t {print $2, n, $0}' |
    sed -E 's/^([0-9:.]+) ([a-z0-9]+) .*\] [a-zA-Z]+ -> (.*) channel=.*/\1 \2: \3/'
done | sort
r=$("$HERE/../../chapter-04/scripts/submit.sh" "$CH" "$C" "${PORT[$C]}" \
  "e-$CH-$(date +%s)")
echo "$(ms) first transaction after the election:"
echo "             ${r#* via }"
$NODE_CTL start "$L.example.com" >/dev/null
for i in $(seq 60); do
  [ "$(metric "$N" consensus_etcdraft_active_nodes)" = 3 ] && break; sleep 1
done
echo "$(ms) $L restarted; active consenters:" \
  "$(metric "$N" consensus_etcdraft_active_nodes)"
