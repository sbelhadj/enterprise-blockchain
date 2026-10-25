#!/usr/bin/env bash
#
# Listing 1.5: what peer0.org1 knows about the channel. Run from fabric-samples/test-network.
set -euo pipefail
source "$(dirname "$0")/org1-env.sh"
peer channel list
peer channel getinfo -c mychannel
peer lifecycle chaincode querycommitted -C mychannel -n basic
