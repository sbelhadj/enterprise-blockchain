#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 4. Author's script, not a reader step.
# Network: the four-orderer test network (./network.sh up -bft), run as local processes.
# mychannel uses SmartBFT on all four nodes; raftchannel uses Raft on orderer, orderer2, orderer3.
# The drills stop and start nodes through testnet-native.sh, which stands in for docker stop/start.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/chapter-04
TN=$SAMPLES/test-network
CH=$REPO/chapter-04
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
export NODE_CTL=$REPO/tools/native/testnet-native.sh
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" -e "s#$(dirname "$REPO")#~#g"; }

# The SmartBFT profile as fabric-samples ships it (commit 5789681)
# (shortened for print: ORD stands for ../organizations/ordererOrganizations/example.com/orderers,
# and the profile's two leading spaces of indentation are removed)
sed -n '/^  ChannelUsingBFT:/,/^    Application:/p' "$TN/bft-config/configtx.yaml" | sed '$d' |
  sed -e 's#\.\./organizations/ordererOrganizations/example\.com/orderers#ORD#g' -e 's/^  //' \
  > "$OUT/bft-profile.txt"

cd "$TN"
"$NODE_CTL" down
"$NODE_CTL" up -bft || exit 1
# ./network.sh createChannel -bft runs this script with BFT=1
( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/bft-config VERBOSE=false
  scripts/createChannel.sh mychannel 3 5 false 1 ) 2>&1 | clean > "$OUT/create-bft-channel.txt"
"$CH/scripts/create-raft-channel.sh" 2>&1 | clean > "$OUT/create-raft-channel.txt"
for c in mychannel raftchannel; do
  ./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-typescript -ccl typescript \
    -c $c > /dev/null 2>&1
done
"$CH/scripts/consensus-status.sh" 2>&1 | clean > "$OUT/status-healthy.txt"
"$CH/scripts/bft-drill.sh" 2>&1 | clean > "$OUT/bft-drill.txt"
# The SmartBFT timers at work: forwarding, complaints, heartbeat timeouts and view changes, from
# the node logs (trimmed: date, log sequence number, logger name and channel removed)
for n in orderer orderer2 orderer3 orderer4; do
  sed 's/\x1b\[[0-9;]*m//g' "$REPO/work/native/$n.log" | grep 'channel=mychannel' |
    grep -E 'timeout expired|Failed sending transaction|complaining|ChangeRole' |
    sed -E -e "s/^[0-9-]+ ([0-9:.]+) [A-Z]+ [0-9a-f]+ ([A-Z]+) \[[^]]*\] /\1 $n \2 /" \
      -e 's/ channel=mychannel.*//' -e 's/Request \{[0-9a-f]+ ([0-9a-f]{8})[0-9a-f]*\}/request \1/'
done | sort > "$OUT/bft-drill-log.txt"
"$CH/scripts/raft-drill.sh" 2>&1 | clean > "$OUT/raft-drill.txt"
"$NODE_CTL" down
echo "captured into $OUT"; ls -l "$OUT"
