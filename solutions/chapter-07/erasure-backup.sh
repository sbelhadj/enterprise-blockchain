#!/usr/bin/env bash
#
# Appendix A, Exercise 7.2: an applicant's contact details in lcBankTerms, a
# backup of ExportBank's peer volume, then an erasure. What is left, and where?
# Run after Listing 7.5. Under Docker the backup uses an alpine container; VOLDIR
# points at the volume folders when the nodes run as local processes.
set -euo pipefail
source "$(dirname "$0")/../../chapter-07/scripts/env.sh"
ID=LC-72 PHONE='+216 71 555 0172'
CONTACT=$(jq -cn --arg p "$PHONE" '{contactName: "Leila Ben Salah", phone: $p}')
W=$CH5/channel-artifacts/ex7-2; rm -rf "$W"; mkdir -p "$W"
VOL=lcnet_peer0.exportbank.example.com
backup() {  # a tar of the peer's volume, taken while the peer is stopped
  if [ -n "${VOLDIR:-}" ]; then
    tar -C "$VOLDIR/${VOL#lcnet_}" -czf "$W/backup.tgz" .
  else docker run --rm -v "$VOL:/v:ro" -v "$W:/b" alpine tar -C /v -czf \
    /b/backup.tgz .; fi
}
in_backup() {  # files of the backup that contain the telephone number
  rm -rf "$W/restore"; mkdir -p "$W/restore"
  tar -C "$W/restore" -xzf "$W/backup.tgz"
  grep -r -l -a -F "$PHONE" "$W/restore" | sed "s#$W/restore/##" | sed 's/^/    /'
}

echo "== 1. ImportBank stores the contact details"
use importbank user1
terms_submit "${BANK_PEERS[@]}" -- PutTerms "$ID" "$(terms_json "$CONTACT")"
use exportbank user1; echo "  ExportBank reads: $(terms_query ReadTerms "$ID")"

echo "== 2. A backup of peer0.exportbank's volume, before any erasure request"
$COMPOSE stop peer0-exportbank 2>&1 | grep Error || true
backup
$COMPOSE start peer0-exportbank 2>&1 | grep Error || true
for i in $(seq 30); do curl -sf localhost:7443/healthz >/dev/null && break; sleep 1
done
echo "  backup: $(du -h "$W/backup.tgz" | cut -f1); files with the number:"
in_backup

echo "== 3. The erasure request: ImportBank purges the record"
sleep 5
use importbank user1
echo "  $(terms_submit "${BANK_PEERS[@]}" -- PurgeTerms "$ID")"
for o in exportbank importbank customs; do
  use $o user1; echo "  $MSP: $(terms_query ReadTerms "$ID" | cut -c1-60)"
done

echo "== 4. The live volume, and the backup, after the purge"
$COMPOSE stop peer0-exportbank 2>&1 | grep Error || true
mv "$W/backup.tgz" "$W/before.tgz"; backup; mv "$W/backup.tgz" "$W/after.tgz"
$COMPOSE start peer0-exportbank 2>&1 | grep Error || true
for i in $(seq 30); do curl -sf localhost:7443/healthz >/dev/null && break; sleep 1
done
cp "$W/after.tgz" "$W/backup.tgz"
echo "  live volume, files with the number:"; in_backup; echo "    (end)"
cp "$W/before.tgz" "$W/backup.tgz"
echo "  backup from step 2, files with the number:"; in_backup
