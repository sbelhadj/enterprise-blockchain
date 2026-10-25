#!/usr/bin/env bash
#
# Captures the outputs printed in Chapter 2. Author's script, not a reader step.
# Starts from the Chapter 1 end state (setup-chapter-01-state.sh). Rewrites as in chapter-01.sh.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/chapter-02
TN=$SAMPLES/test-network
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g"; }

"$REPO/tools/capture/setup-chapter-01-state.sh" || exit 1
cd "$TN"
"$REPO/chapter-02/inspect-msp.sh" 2>&1 | clean > "$OUT/listing-2-1-inspect-msp.txt"
"$REPO/chapter-02/decode-config.sh" 2>&1 | clean > "$OUT/listing-2-2-decode-config.txt"
"$REPO/chapter-02/trace-tx.sh" 2>&1 | clean > "$OUT/listing-2-3-trace-tx.txt"
"$REPO/chapter-02/mvcc-conflict.sh" 2>&1 | clean > "$OUT/listing-2-4-mvcc-conflict.txt"
# Not printed: the folders a peer keeps under its file system path (checked for Table 2.2)
( cd "$REPO/work/native/peer0org1" && find . -maxdepth 3 -type d | grep -v '^\./logs' | sort ) > "$OUT/peer-data-folders.txt"
echo "captured into $OUT"; ls -l "$OUT"
