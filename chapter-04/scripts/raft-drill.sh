#!/usr/bin/env bash
#
# Listing 4.6: the Raft failure drill on raftchannel (three consenters).
# Run from fabric-samples/test-network after Listing 4.4. Under Docker the
# defaults work as printed; NODE_CTL lets the same script drive another
# runtime (the book's captures ran the nodes as local processes).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
NODE_CTL=${NODE_CTL:-docker}
declare -A PORT=([orderer]=7050 [orderer2]=7052 [orderer3]=7056)
declare -A OPS=([orderer]=9443 [orderer2]=9446 [orderer3]=9447)
metric() {  # metric NODE NAME: one raftchannel metric of one node
  curl -s --max-time 2 "http://localhost:${OPS[$1]}/metrics" |
    awk -v k="$2{channel=\"raftchannel\"}" '$1 == k {print $2}'
}
leader() {  # the consenter that reports is_leader 1, if any
  for n in orderer orderer2 orderer3; do
    [ "$(metric $n consensus_etcdraft_is_leader)" = 1 ] && echo $n
  done
  return 0
}
since() { printf '%.1f' "$(echo "$(date +%s.%N) - $1" | bc)"; }
brief() {  # keep the time, level, function and message of a log line
  sed -E -e 's/\x1b\[[0-9;]*m//g' -e 's/ channel=.*//' \
    -e 's/^[0-9-]+ ([0-9:.]+) [A-Z]+ [0-9a-f]+ ([A-Z]+) \[[^]]*\] /\1 \2 /'
}
RUN=$(date +%s)   # makes asset ids unique if you repeat the drill
submit() {  # create asset raft-RUN-N through the client's ordering node
  "$HERE/submit.sh" raftchannel "$CLIENT" "${PORT[$CLIENT]}" "raft-$RUN-$1"
}

echo "== 1. Healthy cluster"
"$HERE/consensus-status.sh"
L=$(leader); F=($(printf '%s\n' orderer orderer2 orderer3 | grep -vx "$L"))
CLIENT=${F[0]}; OTHER=${F[1]}
echo "leader: $L; the client sends to $CLIENT"
submit 1

echo "== 2. Stop the leader at $(date +%H:%M:%S.%3N)"
t0=$(date +%s.%N)
$NODE_CTL stop "$L.example.com"
until NEW=$(leader) && [ -n "$NEW" ]; do sleep 0.2; done
echo "new leader $NEW elected after $(since "$t0") s"
$NODE_CTL logs "$CLIENT.example.com" 2>&1 | grep 'channel=raftchannel' |
  grep -E 'Raft leader changed|became (candidate|leader)|lost leader' |
  tail -3 | brief
submit 2

echo "== 3. Stop a second node: one consenter of three is left"
$NODE_CTL stop "$OTHER.example.com"
sleep 8
"$HERE/consensus-status.sh"
submit 3

echo "== 4. Restart both stopped nodes"
t0=$(date +%s.%N)
$NODE_CTL start "$L.example.com"; $NODE_CTL start "$OTHER.example.com"
until NEW=$(leader) && [ -n "$NEW" ]; do sleep 0.2; done
echo "leader $NEW elected $(since "$t0") s after the restart"
submit 4
for i in $(seq 60); do
  [ "$(metric "$NEW" consensus_etcdraft_active_nodes)" = 3 ] && break; sleep 1
done
echo "all three consenters active $(since "$t0") s after the restart"
"$HERE/consensus-status.sh"
