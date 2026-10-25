#!/usr/bin/env bash
#
# Appendix A, Exercise 2.2: the ten questions answered from work/config.json, each
# with the jq path that answers it. Run after chapter-02/decode-config.sh.
set -euo pipefail
C=$(cd "$(dirname "$0")/../.." && pwd)/work/config.json
A=.channel_group.groups.Application O=.channel_group.groups.Orderer
ask() {  # ask N PATH [FILTER]: the question number, the path, the value
  local shown; shown=$(sed -e "s/^$A/\$A/" -e "s/^$O/\$O/" <<< "$2")
  printf 'Q%-2s %s\n    %s\n' "$1" "$shown" "$(jq -c "$2${3:-}" "$C")"
}
echo "A is $A, O is $O"
pol=' | "\(.mod_policy // "") \(.policy.value.rule // "")'
pol+=' \(.policy.value.sub_policy // "")"'
ask 1 ".channel_group.mod_policy"
ask 1 ".channel_group.policies.Admins" "$pol"
ask 2 "$A.policies.Admins" "$pol"
ask 2 "$A.groups" " | keys"
ask 2 "$O.groups" " | keys"
ask 3 ".channel_group.values.Capabilities.value.capabilities" " | keys"
ask 3 "$O.values.Capabilities.value.capabilities" " | keys"
ask 3 "$A.values.Capabilities.value.capabilities" " | keys"
ask 4 "$O.values.ConsensusType.value.metadata.consenters" \
  ' | map("\(.host):\(.port)")'
ask 5 "$O.values.BatchTimeout.value.timeout"
ask 6 "$A.groups.Org1MSP.policies.Endorsement.policy.value" \
  ' | {rule, ids: [.identities[].principal | "\(.msp_identifier).\(.role)"]}'
R=$A.groups.Org2MSP.values.MSP.value.config.root_certs[0]
ask 7 "$R" ' | length'
jq -r "$R" "$C" | base64 -d |
  openssl x509 -noout -subject -enddate -nameopt compat |
  sed -e 's#.*CN=#    CN #' -e 's/notAfter=/    valid until /'
ask 8 "$A.policies.Readers" "$pol"
ask 8 "$A.groups.Org1MSP.policies.Readers.policy.value.identities" \
  ' | map(.principal.role)'
ask 9 "$A.groups.Org2MSP.values.AnchorPeers.value.anchor_peers"
ask 10 ".channel_group.values.OrdererAddresses.value.addresses"
