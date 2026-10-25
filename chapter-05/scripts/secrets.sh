#!/usr/bin/env bash
#
# Listing 5.1: generates the bootstrap passwords of the six CAs into
# .secrets/ca.env, once.
# The folder is ignored by Git and readable by its owner only.
set -euo pipefail
CH5=$(cd "$(dirname "$0")/.." && pwd)
[ -s "$CH5/.secrets/ca.env" ] && exit 0
umask 077
mkdir -p "$CH5/.secrets"
for org in EXPORTBANK IMPORTBANK CUSTOMS; do
  for ca in CA TLSCA; do
    echo "${org}_${ca}_ADMINPW=$(openssl rand -hex 16)"
  done
done > "$CH5/.secrets/ca.env"
