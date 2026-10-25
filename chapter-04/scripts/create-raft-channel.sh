#!/usr/bin/env bash
#
# Listing 4.3: create raftchannel, a Raft channel on orderer, orderer2 and
# orderer3 of the network started with ./network.sh up -bft, and join both
# peers. Run from fabric-samples/test-network.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(cd "$HERE/../.." && pwd)/work/chapter-04
ORG=${PWD}/organizations/ordererOrganizations/example.com
ADMIN=$ORG/users/Admin@example.com/tls      # the orderer org admin's TLS keys
mkdir -p "$WORK"
export PATH=${PWD}/../bin:$PATH FABRIC_LOGGING_SPEC=INFO:grpc=error
brief() {  # keep the time, level, function and message of a log line
  sed -E -e 's/\x1b\[[0-9;]*m//g' \
    -e 's/^[0-9-]+ ([0-9:.]+) [A-Z]+ [0-9a-f]+ ([A-Z]+) \[[^]]*\] /\1 \2 /'
}

# test-network's BFT configuration plus our Raft profile, with absolute paths
sed "s#\.\./organizations#${PWD}/organizations#g" bft-config/configtx.yaml \
  > "$WORK/configtx.yaml"
sed "s#ORDERERS#$ORG/orderers#g" "$HERE/../config/raft3-profile.yaml" \
  >> "$WORK/configtx.yaml"
FABRIC_CFG_PATH=$WORK configtxgen -profile ChannelUsingRaft3 \
  -channelID raftchannel -outputBlock "$WORK/raftchannel.block" 2>&1 |
  grep -E 'orderer type|Writing genesis' | brief

# Join the three consenters through the channel participation API,
# authenticating as the orderer organization's administrator
for spec in orderer:7053 orderer2:7055 orderer3:7057; do
  name=${spec%:*}; port=${spec#*:}
  osnadmin channel join --channelID raftchannel \
    --config-block "$WORK/raftchannel.block" -o "localhost:$port" \
    --ca-file "$ORG/orderers/$name.example.com/tls/ca.crt" \
    --client-cert "$ADMIN/client.crt" --client-key "$ADMIN/client.key" |
    grep -E 'Status|"status"|height'
done

# Join both peers
for org in org1 org2; do
  source "$HERE/../../chapter-03/scripts/env.sh" $org
  peer channel join -b "$WORK/raftchannel.block" 2>&1 |
    grep -o 'Successfully submitted.*'
done
