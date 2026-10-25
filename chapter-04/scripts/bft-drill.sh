#!/usr/bin/env bash
#
# Listing 4.7: the SmartBFT failure drill on mychannel (four consenters, so
# f = 1). Run from fabric-samples/test-network after Listing 4.4, on a fresh
# network or after the cluster has settled. NODE_CTL works as in raft-drill.sh.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
NODE_CTL=${NODE_CTL:-docker}
NAMES=([1]=orderer [2]=orderer2 [3]=orderer3 [4]=orderer4)  # ConsenterMapping IDs
declare -A PORT=([orderer]=7050 [orderer2]=7052 [orderer3]=7056 [orderer4]=7058)
bft_leader() {  # the leader's name, as reported by the first node that is up
  local key='consensus_smartbft_view_leader_id{channel="mychannel"}' m
  for p in 9443 9446 9447 9448; do
    m=$(curl -s --max-time 2 "http://localhost:$p/metrics") || continue
    echo "${NAMES[$(awk -v k="$key" '$1 == k {print $2}' <<< "$m")]}"
    return
  done
}
since() { printf '%.0f' "$(echo "$(date +%s.%N) - $1" | bc)"; }
brief() {  # keep the time, level, function and message of a log line
  sed -E -e 's/\x1b\[[0-9;]*m//g' -e 's/ channel=.*//' \
    -e 's/^[0-9-]+ ([0-9:.]+) [A-Z]+ [0-9a-f]+ ([A-Z]+) \[[^]]*\] /\1 \2 /'
}
RUN=$(date +%s)
submit() {  # create asset bft-RUN-N through the client's ordering node
  "$HERE/submit.sh" mychannel "$CLIENT" "${PORT[$CLIENT]}" "bft-$RUN-$1"
}

echo "== 1. Healthy cluster"
"$HERE/consensus-status.sh"
L=$(bft_leader)
F=($(printf '%s\n' orderer orderer2 orderer3 orderer4 | grep -vx "$L"))
CLIENT=${F[0]}; SECOND=${F[1]}
echo "leader: $L; the client sends to $CLIENT"
submit 1

echo "== 2. Stop the leader: three of four nodes remain, enough for 2f + 1 = 3"
t0=$(date +%s.%N)
$NODE_CTL stop "$L.example.com"
submit 2
until [ "$(bft_leader)" != "$L" ]; do sleep 1; done
echo "view change to leader $(bft_leader) completed $(since "$t0") s after the stop"
$NODE_CTL logs "$CLIENT.example.com" 2>&1 | grep 'channel=mychannel' |
  grep 'ChangeRole' | tail -1 | brief
submit 3

echo "== 3. Stop a second node: two of four remain, fewer than 2f + 1"
$NODE_CTL stop "$SECOND.example.com"
"$HERE/consensus-status.sh"
submit 4

echo "== 4. Restart both stopped nodes and wait until ordering works again"
t0=$(date +%s.%N)
$NODE_CTL start "$L.example.com"; $NODE_CTL start "$SECOND.example.com"
for n in $(seq 8); do
  out=$(submit "5-$n"); grep -q VALID <<< "$out" && break
done
echo "$out"
echo "ordering resumed $(since "$t0") s after the restart, on attempt $n"
"$HERE/consensus-status.sh"
