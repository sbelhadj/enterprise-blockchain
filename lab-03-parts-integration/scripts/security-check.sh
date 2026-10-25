#!/usr/bin/env bash
#
# Listing L3.10: Part E security checklist. Each line is a check a reviewer can
# repeat; NOTE lines are accepted exceptions, explained in the integration report.
set -uo pipefail
source "$(dirname "$0")/env.sh"
REPO=$(cd "$LAB/.." && pwd) fails=0
check() {  # check DESCRIPTION COMMAND...: PASS if the command succeeds
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $d"
  else echo "FAIL  $d"; fails=$((fails + 1)); fi
}
perm() { [ "$(stat -c %a "$1")" = "$2" ]; }
all_perm() { local f; for f in $1; do perm "$f" "$2" || return 1; done; }
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

check "wallet keys are readable by the service account only (600)" \
  all_perm "$SVC/wallet/*/key.pem" 600
check "wallet and secrets folders are closed to others (700)" \
  all_perm "$SVC/wallet $SVC/.secrets $SVC/data" 700
check "the users file holds key hashes, not keys" \
  bash -c "! grep -F -f <(cut -d= -f2 '$SVC/.secrets/api-keys.env') \
    '$SVC/.secrets/api-users.json'"
ignored() {
  local p; for p; do git -C "$REPO" check-ignore -q "$p" || return 1; done
}
check "wallet, secrets, data and build are ignored by Git" \
  ignored "$SVC/wallet" "$SVC/.secrets" "$SVC/data" "$LAB/build"
check "no key or secret file is tracked by Git" \
  bash -c "! git -C '$REPO' ls-files | grep -E '(_sk|key\.pem|\.secrets/|wallet/)'"
check "every peer connection uses TLS (no createInsecure)" \
  bash -c "! grep -r createInsecure '$SVC/src'"
check "requests without an API key are refused (401)" \
  test "$(status "$URL/parts/ESN-1001")" = 401
check "a wrong API key is refused (401)" test "$(status \
  -H 'authorization: Bearer 0123456789abcdef' "$URL/parts/ESN-1001")" = 401
check "the API listens on 127.0.0.1 only" \
  bash -c "! curl -s -m 2 http://$(hostname -I | awk '{print $1}'):${PORT:-3000}/"
check "an MRO user cannot act as the airline (403)" \
  test "$(api karim POST /parts/ESN-1001/cycles '{"cycles":1}' | cut -c1-3)" = 403
check "the generator binds CouchDB ports to 127.0.0.1" \
  grep -q '"127.0.0.1:$((BASE + 84)):5984"' "$NET/lib/generate.sh"
check "production dependencies have no known vulnerabilities (npm audit)" \
  bash -c "cd '$SVC' && npm audit --omit=dev --audit-level=low"
echo "NOTE  the API speaks plain HTTP on 127.0.0.1; TLS ends at a reverse proxy"
echo "NOTE  API keys sit in .secrets/api-keys.env for the lab scripts only"
echo "$fails check(s) failed"
