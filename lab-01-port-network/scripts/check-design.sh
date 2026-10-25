#!/usr/bin/env bash
#
# Listing L1.2: Part A design checklist. Checks a network file before anything is
# generated. Usage: check-design.sh [NETWORK.json] (default: ../network.json)
set -uo pipefail
F=${1:-$(dirname "$0")/../network.json}
fails=0
check() {  # check DESCRIPTION JQ-EXPRESSION: PASS if the expression is true
  if [ "$(jq -r "$2" "$F")" = true ]; then echo "PASS  $1"
  else echo "FAIL  $1"; fails=$((fails + 1)); fi
}
F_ORGS='[.orgs[] | select(.joins != "later")]'
check "organization names are lowercase letters and unique" \
  '[.orgs[].name] | (all(test("^[a-z]+$")) and (length == (unique | length)))'
check "MSP IDs are unique" '[.orgs[].msp] | length == (unique | length)'
check "port blocks are 1000 apart and inside 1024 to 65000" \
  '[.orgs[].base] | sort | (all(. >= 1024 and . + 999 <= 65000)) and
   ([range(1; length) as $i | .[$i] - .[$i - 1] >= 1000] | all)'
check "an odd number of founding orderers, at least three" \
  "[$F_ORGS[] | select(.orderer == true)] | length | (. >= 3 and . % 2 == 1)"
check "channel name is valid: lowercase, starts with a letter" \
  '.channel | test("^[a-z][a-z0-9.-]{0,248}$")'
check "at least two founding organizations to endorse" "$F_ORGS | length >= 2"
check "organizations that join later run no orderer" \
  '[.orgs[] | select(.joins == "later") | .orderer // false] | all(. == false)'
check "state database is CouchDB or goleveldb" \
  '.statedb == "CouchDB" or .statedb == "goleveldb"'
cc=$(dirname "$F")/$(jq -r .chaincode.path "$F")
if [ -f "$cc/package.json" ] && [ -f "$cc/Dockerfile" ]; then
  echo "PASS  chaincode folder has package.json and a Dockerfile"
else
  echo "FAIL  chaincode folder has package.json and a Dockerfile"
  fails=$((fails + 1))
fi
n=$(jq "[$F_ORGS[] | select(.orderer == true)] | length" "$F")
echo "Raft: $n orderers tolerate $(( (n - 1) / 2 )) failed; $fails check(s) failed"
[ $fails -eq 0 ]
