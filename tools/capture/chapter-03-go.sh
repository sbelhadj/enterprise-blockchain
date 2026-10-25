#!/usr/bin/env bash
#
# Builds and vets the Go version of the chaincode (Section 3.11). Author's script.
# The authoring machine cannot reach proxy.golang.org or vanity import hosts, so this script
# builds a copy in work/go-build whose go.mod maps those modules to their GitHub mirrors.
# The repository's own go.mod is the standard one; readers run go mod tidy against the Go proxy.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$REPO/chapter-03/lc-chaincode-go
W=$REPO/work
OUT=$REPO/captured-outputs/chapter-03
export GOPROXY=direct GOSUMDB=off GOFLAGS=-mod=mod GOTOOLCHAIN=local
[ -d "$W/go-yaml" ] || git clone -q --branch v3.0.4 --depth 1 https://github.com/yaml/go-yaml.git "$W/go-yaml"
[ -d "$W/go-check" ] || { git clone -q https://github.com/go-check/check.git "$W/go-check" &&
  git -C "$W/go-check" checkout -q 20d25e280405 && printf 'module gopkg.in/check.v1\n' > "$W/go-check/go.mod"; }
rm -rf "$W/go-build" && mkdir -p "$W/go-build" && cp "$SRC"/go.mod "$SRC"/*.go "$W/go-build/"
cat >> "$W/go-build/go.mod" <<'MIRRORS'

replace (
	golang.org/x/net => github.com/golang/net v0.48.0
	golang.org/x/sys => github.com/golang/sys v0.39.0
	golang.org/x/text => github.com/golang/text v0.32.0
	google.golang.org/genproto/googleapis/rpc => github.com/googleapis/go-genproto/googleapis/rpc v0.0.0-20251202230838-ff82c1b0f217
	google.golang.org/grpc => github.com/grpc/grpc-go v1.79.3
	google.golang.org/protobuf => github.com/protocolbuffers/protobuf-go v1.36.11
	go.yaml.in/yaml/v3 => ../go-yaml
	gopkg.in/check.v1 => ../go-check
)
MIRRORS
cd "$W/go-build"
{
  echo '$ go version'; go version
  echo '$ go build -o lc-chaincode-go . && go vet .'
  go build -o lc-chaincode-go . && go vet . && echo "build and vet: no problems reported"
  echo '$ go list -m github.com/hyperledger/fabric-contract-api-go/v2 github.com/hyperledger/fabric-chaincode-go/v2'
  go list -m github.com/hyperledger/fabric-contract-api-go/v2 github.com/hyperledger/fabric-chaincode-go/v2
} 2>&1 | grep -v '^go: downloading' > "$OUT/go-build.txt"
cat "$OUT/go-build.txt"
