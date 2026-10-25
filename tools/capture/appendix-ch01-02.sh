#!/usr/bin/env bash
#
# Captures the Appendix A outputs for Exercises 1.3 and 2.1 to 2.4, on the native
# test network at the Chapter 1 end state. Author's script, not a reader step.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SAMPLES=${SAMPLES:-$HOME/fabric-samples}
OUT=$REPO/captured-outputs/appendix TN=$SAMPLES/test-network S=$REPO/solutions
mkdir -p "$OUT"
export NO_PROXY="${NO_PROXY:-localhost},.example.com" no_proxy="${no_proxy:-localhost},.example.com"
export FABRIC_LOGGING_SPEC=INFO:grpc=error
clean() { sed -e 's/\x1b\[[0-9;]*m//g' -e "s#$(dirname "$SAMPLES")#~#g" | grep -v InitCmdFactory; }
"$REPO/tools/capture/setup-chapter-01-state.sh" || exit 1
cd "$TN"
"$S/chapter-01/experiments.sh" 2>&1 | clean > "$OUT/ex1-3-experiments.txt"
"$S/chapter-02/msp-table.sh" 2>&1 | clean > "$OUT/ex2-1-msp-table.txt"
"$REPO/chapter-02/decode-config.sh" > /dev/null 2>&1
"$S/chapter-02/config-answers.sh" 2>&1 | clean > "$OUT/ex2-2-config-answers.txt"
"$REPO/chapter-02/trace-tx.sh" > /dev/null 2>&1
"$S/chapter-02/mvcc-three.sh" 2>&1 | clean > "$OUT/ex2-3-mvcc-three.txt"
"$S/chapter-02/policy-and.sh" 2>&1 | clean > "$OUT/ex2-4-policy-and.txt"
"$REPO/tools/native/testnet-native.sh" down
cd "$OUT" && cat ex1-3-experiments.txt ex2-1-msp-table.txt ex2-2-config-answers.txt \
  ex2-3-mvcc-three.txt ex2-4-policy-and.txt
