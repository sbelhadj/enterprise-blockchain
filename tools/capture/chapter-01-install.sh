#!/usr/bin/env bash
#
# Captures Listing 1.1 (install the Fabric 3.1.5 binaries and fabric-samples). Author's script.
# Runs in an empty scratch directory that stands in for the reader's home directory, which
# the output shows as "~". curl progress meters are removed; nothing else is changed.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$REPO/captured-outputs/chapter-01
WORK=${WORK:-$(mktemp -d)}
cd "$WORK"
clean() { tr '\r' '\n' | grep -v -E '^ *[0-9]+ +[0-9.]+[kMG]? +[0-9]+|% Total|Dload' | sed "s#$WORK#~#g"; }
{
  echo '$ curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh'
  curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh
  chmod +x install-fabric.sh
  echo '$ ./install-fabric.sh --fabric-version 3.1.5 --ca-version 1.5.22 binary samples'
  ./install-fabric.sh --fabric-version 3.1.5 --ca-version 1.5.22 binary samples 2>&1
  echo '$ git -C fabric-samples checkout -q 5789681 && git -C fabric-samples log --oneline -1'
  git -C fabric-samples checkout -q 5789681 && git -C fabric-samples log --oneline -1
  echo '$ export PATH=~/fabric-samples/bin:$PATH'
  export PATH=$WORK/fabric-samples/bin:$PATH
  echo '$ peer version'
  peer version
  echo '$ fabric-ca-client version'
  fabric-ca-client version
} 2>&1 | clean > "$OUT/listing-1-1-install.txt"
cat "$OUT/listing-1-1-install.txt"
