# Running Fabric 3.1 natively: findings from Phase 1 (24 October 2026)

These notes record what it took to run fabric-samples' test-network-nano-bash (main at commit
5789681) with the Fabric 3.1.5 and Fabric CA 1.5.22 release binaries and no Docker. They feed the
Common Mistakes sections of Chapters 1 and 5 and the scripts in `network/`.

Results:
- Raft (three orderers) with Fabric CA identities, two organizations and four peers: started,
  channel created, TypeScript chaincode (asset-transfer-basic) built by the Node external
  builder, approved, committed, invoked and queried. Transaction status VALID.
- SmartBFT (four orderers) with cryptogen identities: started, same chaincode deployed and
  invoked; the orderer logs show smartbft commit messages from the other consenters.

Problems met, and the fix used:
1. `configureExternalBuilders.sh` inserts its builder list with a different indentation from the
   3.1.5 `core.yaml`, so the peer fails with "yaml: line 571: did not find expected key". Fix:
   write `chaincode.externalBuilders` as a proper YAML list (our scripts generate it).
2. `network.sh` exports `CORE_VM_ENDPOINT` from `docker context inspect` whenever the Docker CLI
   is installed, even when no daemon runs. The peer then registers a Docker health check and
   `/healthz` stays "Service Unavailable". Fix: leave `CORE_VM_ENDPOINT` empty when external
   builders are used.
3. `network.sh start -o BFT -ca` fails in configtxgen: the BFT consenter configuration expects
   cryptogen file names (`orderer.example.com-cert.pem`), while the CA enrollment writes
   `cert.pem`. Fix in our scripts: one naming scheme for both, Fabric CA only.
4. Peers and orderers left over from an interrupted run keep their ports, so a restart silently
   talks to the old processes. Fix: a stop script that kills by anchored command names before
   every start.
5. TypeScript 7.0 rejects the sample `tsconfig.json` (TS5011, rootDir must be explicit);
   TypeScript 5.9.3 builds the fabric-contract-api decorators unchanged. Pinned to 5.9.3.

## Chapter 1 captures (24 October 2026)

`tools/native/testnet-native.sh` runs fabric-samples' test-network nodes (one Raft orderer,
peer0.org1, peer0.org2) as local processes with the environment of `compose/compose-test-net.yaml`,
so `scripts/createChannel.sh`, `./network.sh deployCC` and the peer CLI run unchanged. Findings:

6. `install-fabric.sh` (fetched from main) still defaults to Fabric 2.5.16 and Fabric CA 1.5.17.
   Readers must pass `--fabric-version 3.1.5 --ca-version 1.5.22`. Goes into Chapter 1, Common Mistakes.
7. The 3.1.5 peer CLI logs gRPC connection internals at INFO (dozens of lines per command).
   `FABRIC_LOGGING_SPEC=INFO:grpc=error` removes them; Listing 1.2 sets it.
8. `test-network/setOrgEnv.sh` does not print `CORE_PEER_LOCALMSPID`, so
   `export $(./setOrgEnv.sh Org1 | xargs)` leaves the CLI with the default MSP ID. The book uses
   `chapter-01/org1-env.sh` instead.
9. The Node external builder's `run` script writes chaincode logs to `./logs` relative to the
   peer's working directory and fails ("builder 'node' run failed: exit status 1") if it is
   missing. The harness starts each peer in its data folder with a `logs` subfolder.
10. Authoring machine only: gRPC honours `HTTPS_PROXY`, so node-to-node traffic to the
    `*.example.com` names went to the proxy until `.example.com` was added to `NO_PROXY`.
11. A proposal endorsed by one organization is still ordered into a block and then marked
    `ENDORSEMENT_POLICY_FAILURE` by every peer (Exercise 1.3, Experiment A).
