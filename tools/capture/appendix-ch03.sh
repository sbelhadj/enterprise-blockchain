#!/usr/bin/env bash
#
# Captures the Appendix A outputs for Exercises 3.1, 3.2, 3.3 and 3.5. Author's
# script, not a reader step. Same network as tools/capture/chapter-03.sh: native
# test-network with Fabric CA identities and LevelDB.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/appendix
TN=$SAMPLES/test-network CH=$REPO/chapter-03 SOL=$REPO/solutions/chapter-03
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" -e "s#$(dirname "$REPO")#~#g" |
  grep -v 'InitCmdFactory'; }

( cd "$SOL/lc-chaincode" && rm -rf node_modules dist coverage &&
  npm ci --no-audit --no-fund --loglevel=error >/dev/null &&
  npm run --silent build && npm run lint && npm run coverage ) 2>&1 | clean > "$OUT/ex3-1-tests.txt"

cd "$TN"
"$REPO/tools/native/testnet-native.sh" down
"$REPO/tools/native/testnet-native.sh" up -ca || exit 1
( export PATH=$TN/../bin:$PATH FABRIC_CFG_PATH=$TN/configtx VERBOSE=false
  scripts/createChannel.sh mychannel 3 5 false 0 ) > /dev/null 2>&1
"$CH/scripts/register-officer.sh" >/dev/null 2>&1
issue() { ( source "$CH/scripts/env.sh" org2 lcofficer
  lc_submit IssueLC "$1" 'Tunis Olive Imports' 'Sfax Olive Oil Co' Org1MSP "$2" EUR \
    "$(date -u -d '+180 days' +%F)" 'olive oil' ) 2>&1 | grep -o 'committed with status.*' ; }
"$CH/scripts/deploy-lc.sh" 1.0 1 >/dev/null 2>&1 && issue LC-V10 50000000
"$CH/scripts/deploy-lc.sh" 1.1 2 >/dev/null 2>&1 && issue LC-V11 120000000
"$SOL/deploy-1.2.sh" 2>&1 | clean > "$OUT/ex3-5-deploy.txt"
"$SOL/exercises.sh" 2>&1 | clean > "$OUT/ex3-1-2-5-network.txt"
( source "$CH/scripts/env.sh" org1
  lc_query GetLCsAboveAmount 100000000 10 '' ) 2>&1 | clean |
  sed 's/transaction ID: [0-9a-f]*/transaction ID: .../' | fold -s -w 80 > "$OUT/ex3-3-leveldb.txt"
"$REPO/tools/native/testnet-native.sh" down
ls -l "$OUT"
