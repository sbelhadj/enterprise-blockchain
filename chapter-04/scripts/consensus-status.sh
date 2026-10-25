#!/usr/bin/env bash
#
# Listing 4.5: what each ordering node reports about consensus, read from
# its operations endpoint. Works the same under Docker: the test network
# publishes the operations ports 9443 and 9446 to 9448.
NODES="orderer:9443 orderer2:9446 orderer3:9447 orderer4:9448"
ROW='%-22s %-12s %-14s %-14s %-9s\n'
printf "$ROW" node raft-leader raft-active bft-leader-id bft-view
for n in $NODES; do
  host=${n%:*}.example.com
  m=$(curl -s --max-time 2 "http://localhost:${n#*:}/metrics") ||
    { printf '%-22s %s\n' "$host" 'down'; continue; }
  get() {  # the value of one metric, or - when the node does not report it
    awk -v k="$1" '$1 == k {print $2; f=1} END {if (!f) print "-"}' <<< "$m"
  }
  raft='{channel="raftchannel"}' bft='{channel="mychannel"}'
  printf "$ROW" "$host" \
    "$(get "consensus_etcdraft_is_leader$raft" | sed 's/^1$/yes/; s/^0$/no/')" \
    "$(get "consensus_etcdraft_active_nodes$raft")" \
    "$(get "consensus_smartbft_view_leader_id$bft")" \
    "$(get "consensus_smartbft_view_number$bft")"
done
