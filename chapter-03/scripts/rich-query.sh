#!/usr/bin/env bash
#
# Listing 3.13: a CouchDB rich query through the indexStatus index. Needs a network started
# with -s couchdb; on LevelDB the peer refuses it. Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/env.sh" org1
lc_query QueryLCsByStatus ISSUED 10 "" |
  jq -c '{ids: [.records[].id], fetchedRecordsCount, bookmark}'
