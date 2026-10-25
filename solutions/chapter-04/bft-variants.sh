#!/usr/bin/env bash
#
# Appendix A, Exercise 4.3: on mychannel (SmartBFT, four consenters, f = 1),
# first stop a follower, then stop the leader while a client submits through
# every remaining node. Run from fabric-samples/test-network on a settled network.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
LOAD=$(cd "$HERE/../.." && pwd)/work/chapter-04/bft-load.log   # ignored by Git
mkdir -p "$(dirname "$LOAD")"
S=$HERE/../../chapter-04/scripts
NODE_CTL=${NODE_CTL:-docker}
NAMES=([1]=orderer [2]=orderer2 [3]=orderer3 [4]=orderer4)
declare -A PORT=([orderer]=7050 [orderer2]=7052 [orderer3]=7056 [orderer4]=7058)
declare -A OPS=([orderer]=9443 [orderer2]=9446 [orderer3]=9447 [orderer4]=9448)
view() {  # view NODE: "leader-id view-number" as NODE reports them
  curl -s --max-time 2 "http://localhost:${OPS[$1]}/metrics" | awk '
    $1 == "consensus_smartbft_view_leader_id{channel=\"mychannel\"}" {l = $2}
    $1 == "consensus_smartbft_view_number{channel=\"mychannel\"}" {v = $2}
    END {print l, v}'
}
since() { printf '%.0f' "$(echo "$(date +%s.%N) - $1" | bc)"; }
RUN=$(date +%s)
read -r LID V0 < <(view orderer4); L=${NAMES[$LID]}
FOL=($(printf '%s\n' orderer orderer2 orderer3 orderer4 | grep -vx "$L"))
echo "leader $L, view $V0"

echo "== 1. Stop follower ${FOL[2]}; submit through ${FOL[0]}"
$NODE_CTL stop "${FOL[2]}.example.com" >/dev/null
for i in 1 2 3; do
  "$S/submit.sh" mychannel "${FOL[0]}" "${PORT[${FOL[0]}]}" "f-$RUN-$i"
done
read -r l v < <(view "${FOL[0]}")
echo "leader ${NAMES[$l]}, view $v: no view change"
$NODE_CTL start "${FOL[2]}.example.com" >/dev/null; sleep 20

echo "== 2. Stop leader $L while a client submits through all three others"
( n=0; while [ ! -e "$HERE/.stop" ]; do
    for o in "${FOL[@]}"; do
      n=$((n + 1))
      "$S/submit.sh" mychannel "$o" "${PORT[$o]}" "v-$RUN-$n" &
    done
    sleep 2
  done; wait ) > "$LOAD" 2>&1 &
sleep 4; t0=$(date +%s.%N)
$NODE_CTL stop "$L.example.com" >/dev/null
until read -r l v < <(view "${FOL[0]}") && [ "$l" != "$LID" ] && [ -n "$l" ]; do
  sleep 1
done
echo "view change to leader ${NAMES[$l]} (view $v) $(since "$t0") s after the stop"
T0=$(date -d "@${t0%.*}" +%H:%M:%S)
for o in "${FOL[@]}"; do      # the first complaint and role change on each node
  $NODE_CTL logs "$o.example.com" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' |
    grep 'channel=mychannel' | grep -E 'complain|ChangeRole' |
    awk -v t="$T0" '$2 > t' | sed -E -e 's/ channel=.*//' \
      -e "s/^[0-9-]+ ([0-9:.]+) .*\] ([A-Za-z]+) -> /\1 $o \2: /" | cut -c1-84 |
    awk '!seen[$3]++'
done | sort
sleep 10; touch "$HERE/.stop"; wait; rm -f "$HERE/.stop"
echo "client results: $(grep -c VALID "$LOAD") committed VALID," \
  "$(grep -vc VALID "$LOAD") failed or timed out"
$NODE_CTL start "$L.example.com" >/dev/null
