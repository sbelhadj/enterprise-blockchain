#!/usr/bin/env bash
#
# Appendix A, Exercise 4.2: raft20, a second Raft channel on the same three
# consenters as raftchannel, with ElectionTick 20 instead of 10. Run from
# fabric-samples/test-network after Listing 4.3.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(cd "$HERE/../.." && pwd)/work/chapter-04
ORG=${PWD}/organizations/ordererOrganizations/example.com
ADMIN=$ORG/users/Admin@example.com/tls
export PATH=${PWD}/../bin:$PATH FABRIC_LOGGING_SPEC=INFO:grpc=error
PROFILE=$HERE/../../chapter-04/config/raft3-profile.yaml
mkdir -p "$WORK/raft20"
sed "s#\.\./organizations#${PWD}/organizations#g" bft-config/configtx.yaml \
  > "$WORK/raft20/configtx.yaml"
sed -e "s#ORDERERS#$ORG/orderers#g" -e 's/ChannelUsingRaft3:/ChannelUsingRaft20:/' \
  -e 's/ElectionTick: 10 /ElectionTick: 20 /' "$PROFILE" \
  >> "$WORK/raft20/configtx.yaml"
grep -o 'ElectionTick: [0-9]*' "$WORK/raft20/configtx.yaml"
FABRIC_CFG_PATH=$WORK/raft20 configtxgen -profile ChannelUsingRaft20 \
  -channelID raft20 -outputBlock "$WORK/raft20.block" >/dev/null 2>&1
for spec in orderer:7053 orderer2:7055 orderer3:7057; do
  name=${spec%:*}
  osnadmin channel join --channelID raft20 --config-block "$WORK/raft20.block" \
    -o "localhost:${spec#*:}" \
    --ca-file "$ORG/orderers/$name.example.com/tls/ca.crt" \
    --client-cert "$ADMIN/client.crt" --client-key "$ADMIN/client.key" |
    grep -o 'Status: [0-9]*' | sed "s/^/$name joins raft20: /"
done
for org in org1 org2; do
  source "$HERE/../../chapter-03/scripts/env.sh" $org
  peer channel join -b "$WORK/raft20.block" 2>&1 |
    grep -o 'Successfully submitted.*'
done
