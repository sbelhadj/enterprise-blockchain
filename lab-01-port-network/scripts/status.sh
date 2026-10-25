#!/usr/bin/env bash
#
# Listing L1.7: Part C milestone. Every peer at the same height, and the Raft
# leader as the orderers' own metrics report it.
set -euo pipefail
source "$(dirname "$0")/env.sh"
heights
echo "Raft (consensus_etcdraft_is_leader, consensus_etcdraft_cluster_size):"
raft
