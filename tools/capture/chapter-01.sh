#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 1. Author's script, not a reader step.
#   SAMPLES  fabric-samples checkout made by install-fabric.sh (default ~/fabric-samples)
# Rewrites: the checkout's parent directory becomes "~", ANSI colour codes are removed.
# Host names and ports need no mapping: test-network's scripts and the peer CLI use
# localhost:7050/7051/9051 under Docker as well.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/chapter-01
TN=$SAMPLES/test-network
mkdir -p "$OUT"
TIMEFORMAT='elapsed %R s'
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"

# Listing 1.2 tells the reader to set this; Fabric 3.1's CLI otherwise logs gRPC internals at INFO
export FABRIC_LOGGING_SPEC=INFO:grpc=error
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g"; }

cd "$TN"
"$REPO/tools/native/testnet-native.sh" down
"$REPO/tools/native/testnet-native.sh" up

# Listing 1.2: the channel step of ./network.sh up createChannel -c mychannel
# (network.sh runs scripts/createChannel.sh with these arguments once the nodes are up)
( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/configtx VERBOSE=false
  scripts/createChannel.sh mychannel 3 5 false 0 ) 2>&1 | clean > "$OUT/listing-1-2-create-channel.txt"

# Start from a clean chaincode folder so npm prints what a first-time reader sees
rm -rf "$SAMPLES/asset-transfer-basic/chaincode-typescript/node_modules" "$SAMPLES/asset-transfer-basic/chaincode-typescript/dist"

# Listing 1.3: deploy the TypeScript asset-transfer chaincode
{ time ./network.sh deployCC -ccn basic \
    -ccp ../asset-transfer-basic/chaincode-typescript -ccl typescript; } 2>&1 | clean > "$OUT/listing-1-3-deploycc.txt"

# Listing 1.4: one transaction, its block and the world state
{ time "$REPO/chapter-01/first-transaction.sh"; } 2>&1 | clean > "$OUT/listing-1-4-first-transaction.txt"

# Listing 1.5: channel height and the committed chaincode definition
"$REPO/chapter-01/check-channel.sh" 2>&1 | clean > "$OUT/listing-1-5-check-channel.txt"
rm -f "$OUT/check-channel.txt"
echo "captured into $OUT"
ls -l "$OUT"
