#!/usr/bin/env bash
#
# Appendix A, Exercise 2.3: Listing 2.4 three times, one summary line per run:
# where each transfer landed, its validation code, and the owner that won.
# Run from fabric-samples/test-network.
set -euo pipefail
L2_4=$(dirname "$0")/../../chapter-02/mvcc-conflict.sh
for run in 1 2 3; do
  out=$("$L2_4" 2>&1)
  awk -v run="$run" '
    /^== a.log/ {t = "to CustomsAuthority"} /^== b.log/ {t = "to ShippingLine"}
    /^block:/ {blk[t] = $2 + 0; pos[t] = $NF}
    /^validation code:/ {code[t] = $3}
    /"Owner"/ {match($0, /"Owner":"[A-Za-z]+"/); won = substr($0, RSTART + 9,
      RLENGTH - 10)}
    END {
      printf "run %d: both in block %d, owner afterwards %s\n", run,
        blk["to CustomsAuthority"], won
      for (k in code) printf "  transfer %-20s position %s, code %s\n", k, pos[k],
        code[k]
    }' <<< "$out"
done
