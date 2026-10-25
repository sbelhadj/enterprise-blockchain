#!/usr/bin/env bash
#
# Captures the Appendix A outputs for Exercises 4.2 and 4.3 on the four-orderer
# test network, as tools/capture/chapter-04.sh does, with a third channel,
# raft20. The SmartBFT runs come first, on a fresh network. Author's script.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/appendix TN=$SAMPLES/test-network
S=$REPO/solutions/chapter-04 CH=$REPO/chapter-04
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
export NODE_CTL=$REPO/tools/native/testnet-native.sh
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" -e "s#$(dirname "$REPO")#~#g"; }
cd "$TN"
"$NODE_CTL" down
"$NODE_CTL" up -bft || exit 1
( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/bft-config VERBOSE=false
  scripts/createChannel.sh mychannel 3 5 false 1 ) > /dev/null 2>&1
"$CH/scripts/create-raft-channel.sh" > /dev/null 2>&1
"$S/create-raft20.sh" 2>&1 | clean > "$OUT/ex4-2-create-raft20.txt"
for c in mychannel raftchannel raft20; do
  ./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-typescript \
    -ccl typescript -c $c > /dev/null 2>&1
done
sleep 30
"$S/bft-variants.sh" 2>&1 | clean > "$OUT/ex4-3-bft.txt"
sleep 30
"$S/raft-election.sh" raftchannel 2>&1 | clean > "$OUT/ex4-2-tick10.txt"
sleep 10
"$S/raft-election.sh" raft20 2>&1 | clean > "$OUT/ex4-2-tick20.txt"
"$NODE_CTL" down
cd "$OUT" && cat ex4-2-create-raft20.txt ex4-3-bft.txt ex4-2-tick10.txt ex4-2-tick20.txt
