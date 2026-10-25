#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 3. Author's script, not a reader step.
# The network is test-network with Fabric CA identities (./network.sh up createChannel -ca).
# The peers use LevelDB: CouchDB was not available on the authoring machine, so the CouchDB
# listing is printed without output and the LevelDB refusal is captured for Common Mistakes.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/chapter-03
TN=$SAMPLES/test-network
CH=$REPO/chapter-03
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" -e "s#$(dirname "$REPO")#~#g"; }

# Unit tests, coverage and lint, from a clean install
( cd "$CH/lc-chaincode" && rm -rf node_modules dist && npm ci --no-audit --no-fund --loglevel=error >/dev/null &&
  npm run --silent build && npm run lint && npm run coverage ) 2>&1 | clean > "$OUT/unit-tests.txt"
( cd "$CH/lc-chaincode" && npm run lint:demo ) 2>&1 | clean > "$OUT/lint-demo.txt"

# Network with Fabric CA identities and the channel
cd "$TN"
"$REPO/tools/native/testnet-native.sh" down
"$REPO/tools/native/testnet-native.sh" up -ca || exit 1
( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/configtx VERBOSE=false
  scripts/createChannel.sh mychannel 3 5 false 0 ) > /dev/null 2>&1

"$CH/scripts/register-officer.sh" 2>&1 | clean > "$OUT/register-officer.txt"
"$CH/scripts/deploy-lc.sh" 1.0 1 2>&1 | clean > "$OUT/deploy-1.0.txt"
( cd "$CH/app" && npm ci --no-audit --no-fund --loglevel=error >/dev/null && npm run --silent build &&
  FABRIC_SAMPLES=$SAMPLES npm run --silent issue -- LC-2026-001 ) 2>&1 | clean > "$OUT/gateway-issue.txt"
"$CH/scripts/walk-lc.sh" 2>&1 | clean > "$OUT/walk-lc.txt"
"$CH/scripts/refused.sh" 2>&1 | clean > "$OUT/refused.txt"
"$CH/scripts/page-lcs.sh" 2>&1 | clean > "$OUT/page-lcs.txt"
"$CH/scripts/rich-query.sh" 2>&1 | clean > "$OUT/rich-query-on-leveldb.txt"
"$CH/scripts/read-your-write.sh" 2>&1 | clean > "$OUT/read-your-write.txt"
"$CH/scripts/upgrade-lc.sh" 2>&1 | clean > "$OUT/upgrade-1.1.txt"
"$REPO/tools/native/testnet-native.sh" down
echo "captured into $OUT"; ls -l "$OUT"
