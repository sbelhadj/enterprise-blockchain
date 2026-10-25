#!/usr/bin/env bash
# Download the pinned Fabric and Fabric CA release binaries, check their SHA-256 digests,
# and unpack them into ./fabric (bin/, config/, builders/). Run from the repository root.
# The book's captures were taken with exactly these archives (see VERSIONS.md).
set -euo pipefail
FABRIC_VERSION=3.1.5
CA_VERSION=1.5.22
FABRIC_SHA256=b9c31fd490991e76f8acb1835dee09fc19fee5428cb13e190ee6e0bdd2c37858
CA_SHA256=7f52ab98481ac0e4bfcf5b5aabfb403fa692ee100ae3b2ca3bf3f2152851573d
ARCH=linux-amd64   # macOS readers: darwin-arm64 or darwin-amd64; the digests above are for linux-amd64

mkdir -p fabric && cd fabric
base=https://github.com/hyperledger
curl -sSL -o fabric.tgz "$base/fabric/releases/download/v$FABRIC_VERSION/hyperledger-fabric-$ARCH-$FABRIC_VERSION.tar.gz"
curl -sSL -o ca.tgz "$base/fabric-ca/releases/download/v$CA_VERSION/hyperledger-fabric-ca-$ARCH-$CA_VERSION.tar.gz"
if [ "$ARCH" = linux-amd64 ]; then
  echo "$FABRIC_SHA256  fabric.tgz" | sha256sum -c -
  echo "$CA_SHA256  ca.tgz" | sha256sum -c -
fi
tar xzf fabric.tgz && tar xzf ca.tgz && rm fabric.tgz ca.tgz
./bin/peer version | head -2
./bin/fabric-ca-server version | head -2
echo "Add $(pwd)/bin to your PATH."
