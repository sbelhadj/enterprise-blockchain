#!/usr/bin/env bash
#
# Appendix A, Exercise 7.1: the interest rate and risk rating of a letter of
# credit in lcBankTerms, first without a salt, then with one. CustomsAuthority
# sees only the hash, and tries to guess the terms from it. Run after Listing 7.5.
set -euo pipefail
source "$(dirname "$0")/../../chapter-07/scripts/env.sh"
guess() {  # guess HASH: try every rating A to E and every rate up to 20 percent
  python3 - "$1" <<'PY'
import hashlib, json, sys, time
t, n = time.time(), 0
for rating in 'ABCDE':
    for bps in range(0, 2001):
        n += 1
        c = json.dumps({'interestRateBps': bps, 'riskRating': rating},
                       sort_keys=True, separators=(',', ':'))
        if hashlib.sha256(c.encode()).hexdigest() == sys.argv[1]:
            print(f'{bps} bps, rating {rating}, found in {n} guesses,'
                  f' {time.time() - t:.2f} s')
            sys.exit()
print(f'no match in {n} guesses, {time.time() - t:.2f} s')
PY
}
store_and_attack() {  # store_and_attack ID TERMS
  use importbank user1
  echo "  ImportBank stores $1: $(terms_submit "${BANK_PEERS[@]}" -- PutTerms \
    "$1" "$(terms_json "$2")")"
  for o in exportbank importbank customs; do
    use $o user1
    echo "  $MSP reads: $(terms_query ReadTerms "$1" | cut -c1-58)"
  done
  use customs user1
  echo "  CustomsMSP guesses: $(guess "$(terms_query TermsHash "$1")")"
}

echo "== 1. Without a salt"
store_and_attack LC-71A '{"interestRateBps":410,"riskRating":"B"}'
echo "== 2. With 32 random bytes of salt"
SALTED=$(jq -cn --arg s "$(openssl rand -hex 32)" \
  '{interestRateBps: 410, riskRating: "B", salt: $s}')
store_and_attack LC-71B "$SALTED"
echo "== 3. CustomsAuthority checks the copy ImportBank gave it"
echo "  VerifyTerms: $(terms_query VerifyTerms LC-71B "$(terms_json "$SALTED")")"
