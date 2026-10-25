#!/usr/bin/env bash
#
# Reconciliation (Listing L3.9), before and after someone edits the maintenance
# database by hand.
set -uo pipefail
source "$(dirname "$0")/env.sh"
S=${1:-ESN-1001}
rec() { (cd "$SVC" && npm run --silent reconcile -- "$@"; echo "exit code $?"); }
echo "== in step"
rec
echo "== someone marks $S as installed in the maintenance database"
(cd "$SVC" && node --disable-warning=ExperimentalWarning -e "
  const {DatabaseSync} = require('node:sqlite');
  new DatabaseSync('data/maintenance.db').prepare(
    \"UPDATE parts SET status = 'INSTALLED', aircraft = 'TS-IMX' WHERE serial = ?\"
  ).run('$S');")
rec
echo "== the ledger wins"
rec --fix
rec
