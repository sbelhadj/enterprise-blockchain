#!/usr/bin/env bash
#
# Brings the native test network to the state the reader has at the end of Chapter 1:
# channel mychannel, chaincode basic deployed, asset7 created (block 6). Prints nothing on success.
# Author's script, used by the capture scripts of later chapters.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
TN=$SAMPLES/test-network
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
cd "$TN"
{
  "$REPO/tools/native/testnet-native.sh" down
  "$REPO/tools/native/testnet-native.sh" up
  ( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/configtx VERBOSE=false
    scripts/createChannel.sh mychannel 3 5 false 0 )
  ./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-typescript -ccl typescript
  "$REPO/chapter-01/first-transaction.sh"
} > /tmp/setup-chapter-01-state.log 2>&1 || { tail -30 /tmp/setup-chapter-01-state.log; exit 1; }
