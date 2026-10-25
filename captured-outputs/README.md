# Captured outputs

Every output printed in Book 4 comes from a file in this folder, produced by a real run with the
versions in VERSIONS.md. Captures are post-processed in these ways only, all mechanical:

- the absolute path of the authoring checkout, or of the folder that stands in for the reader's
  home directory, is replaced with `~`;
- for network captures that use non-standard local addresses, those addresses are rewritten to the
  Docker Compose host names and ports used in the book. Each capture script states the mapping it
  applies (Chapter 1 needs none: test-network uses localhost ports under Docker too);
- terminal colour codes and curl progress meters are removed.

Lines starting with `elapsed` are added by the capture scripts (bash `time`), not by Fabric.
Nothing else is edited. The scripts are in `tools/capture/`, one per chapter.

## chapter-01

| File | Produced by | Notes |
| --- | --- | --- |
| listing-1-1-install.txt | tools/capture/chapter-01-install.sh | `binary samples` components only; the `docker` component needs a Docker daemon and its output is not printed in the book |
| listing-1-2-create-channel.txt | tools/capture/chapter-01.sh | Output of `scripts/createChannel.sh mychannel 3 5 false 0`, the script `./network.sh up createChannel` runs once the nodes are up |
| listing-1-3-deploycc.txt | tools/capture/chapter-01.sh | `./network.sh deployCC` unchanged, from a clean chaincode folder |
| listing-1-4-first-transaction.txt | chapter-01/first-transaction.sh | |
| listing-1-5-check-channel.txt | chapter-01/check-channel.sh | |

The network nodes for these captures ran as local processes started by
`tools/native/testnet-native.sh`, with the same host names, ports, environment and cryptogen
material as test-network's Compose files. See docs/native-runs.md.

## chapter-02

All files come from `tools/capture/chapter-02.sh`, which first brings the native test network to
the Chapter 1 end state with `tools/capture/setup-chapter-01-state.sh` (asset7 created in block 6).

| File | Produced by |
| --- | --- |
| listing-2-1-inspect-msp.txt | chapter-02/inspect-msp.sh |
| listing-2-2-decode-config.txt | chapter-02/decode-config.sh |
| listing-2-3-trace-tx.txt | chapter-02/trace-tx.sh |
| listing-2-4-mvcc-conflict.txt | chapter-02/mvcc-conflict.sh; which transfer wins varies from run to run |
| peer-data-folders.txt | Not printed; the folder list behind Table 2.2, from the native peer's file system path |

## chapter-03

`tools/capture/chapter-03.sh` runs the unit tests and lint from a clean `npm ci`, then starts the
native test network with Fabric CA identities (`testnet-native.sh up -ca`, the equivalent of
`./network.sh up createChannel -c mychannel -ca`) and runs the chapter scripts in order. The peers
use LevelDB, so `rich-query-on-leveldb.txt` records the refusal printed in Common Mistakes.
`tools/capture/chapter-03-go.sh` builds the Go chaincode; see the note in that script about
module mirrors on the authoring machine.

| File | Produced by |
| --- | --- |
| unit-tests.txt, lint-demo.txt | npm run lint, npm run coverage, npm run lint:demo in chapter-03/lc-chaincode |
| register-officer.txt | chapter-03/scripts/register-officer.sh (the enrollment secret is replaced by the script) |
| deploy-1.0.txt | chapter-03/scripts/deploy-lc.sh 1.0 1 |
| gateway-issue.txt | npm run issue -- LC-2026-001 in chapter-03/app |
| walk-lc.txt, refused.txt, page-lcs.txt | the scripts of the same names |
| rich-query-on-leveldb.txt | chapter-03/scripts/rich-query.sh on a LevelDB peer |
| read-your-write.txt | chapter-03/scripts/read-your-write.sh |
| upgrade-1.1.txt | chapter-03/scripts/upgrade-lc.sh |
| go-build.txt | tools/capture/chapter-03-go.sh |

## chapter-04

`tools/capture/chapter-04.sh` starts the four-orderer test network as local processes
(`testnet-native.sh up -bft`, the equivalent of `./network.sh up createChannel -bft`), adds the
Raft channel with chapter-04/scripts/create-raft-channel.sh, deploys asset-transfer-basic on both
channels and runs the two drills, SmartBFT first, on a fresh network. The drills stop and start
nodes with `testnet-native.sh stop|start`, which play the role of `docker stop|start`; node logs
are appended across restarts, as `docker logs` keeps them. Timings depend on the machine: the
captures ran all six nodes on one host, so network latency between nodes was negligible.
`tools/capture/chapter-04-legacy.sh` records what Fabric 3.1 does with Solo and Kafka profiles.

| File | Produced by |
| --- | --- |
| bft-profile.txt | The ChannelUsingBFT profile of fabric-samples test-network/bft-config/configtx.yaml; paths shortened to ORDERERS |
| create-bft-channel.txt | Not printed; scripts/createChannel.sh with BFT=1 |
| create-raft-channel.txt | chapter-04/scripts/create-raft-channel.sh |
| status-healthy.txt | chapter-04/scripts/consensus-status.sh on the healthy network |
| bft-drill.txt | chapter-04/scripts/bft-drill.sh |
| bft-drill-log.txt | SmartBFT timer and view change lines from the four node logs during the BFT drill, trimmed (date, log sequence number, logger name and channel removed) |
| raft-drill.txt | chapter-04/scripts/raft-drill.sh |
| legacy-orderer-types.txt | tools/capture/chapter-04-legacy.sh |

## chapter-05

`tools/capture/chapter-05.sh` runs the chapter-05 scripts in order with `DC` set to
`tools/native/compose-native.py`, which runs the services of chapter-05/compose/*.yaml as local
processes (see the docstring of that file). It waits 30 seconds before the operations check so
that gossip membership has been reported. `tools/capture/chapter-05-failures.sh` triggers the ten
failures of Table 5.4 on the running network and restores each one.

| File | Produced by |
| --- | --- |
| ca-up.txt | chapter-05/scripts/ca-up.sh |
| enroll-ORG.txt | chapter-05/scripts/enroll.sh ORG |
| exportbank-tree.txt | find over organizations/exportbank (CA homes excluded, key file names shortened) |
| officer-attributes.txt | openssl x509 -text on the LC officer's certificate, attribute extension only |
| nodes-up.txt, channel.txt, deploy-cc.txt, lc-demo.txt, ops.txt, snapshot.txt, add-customs.txt | the scripts of the same names |
| failures.txt | tools/capture/chapter-05-failures.sh |
| down.txt, network-up.txt | chapter-05/network.sh down, then network.sh up, ops.sh (first lines) and down |

## chapter-06

`tools/capture/chapter-06.sh` starts a fresh Chapter 5 network with the process runner, runs
chapter-06/check-design.sh (Listing 6.2) and removes the network.

| File | Produced by |
| --- | --- |
| check-design.txt | chapter-06/check-design.sh on a fresh Chapter 5 network |

## chapter-07

`tools/capture/chapter-07.sh` starts a fresh Chapter 5 network with the process runner, adds
CustomsAuthority to the application group (Section 5.9), runs the Chapter 7 scripts in order and
removes the network.

| File | Produced by |
| --- | --- |
| deploy-lcterms.txt | chapter-07/scripts/deploy-lcterms.sh (Listing 7.5) |
| private-terms.txt | chapter-07/scripts/private-terms.sh (Listing 7.6) |
| erasure.txt | chapter-07/scripts/erasure.sh (Listing 7.7) |
| revoke.txt | chapter-07/scripts/revoke.sh (Listing 7.8) |
| audit.txt | chapter-07/audit, npm run audit (Listing 7.9) |
| mtls.txt | chapter-07/scripts/mtls-check.sh with compose-mtls.yaml (Listings 7.1 and 7.2) |

## chapter-08

`tools/capture/chapter-08.sh` starts a fresh Chapter 5 network with the process runner, runs the
measurement, the stage metrics and the overload run, and removes the network. Hardware is printed
at the top of measure.txt: every node and the load generator ran on one 2 vCPU machine.

| File | Produced by |
| --- | --- |
| measure.txt, results.csv | chapter-08/scripts/measure.sh (Listing 8.3), which calls batch.sh (Listing 8.1) and the load generator (Listing 8.2) |
| stages-2s-10.txt | chapter-08/scripts/stages.sh 50 20 (Listing 8.4) with BatchTimeout 2s, MaxMessageCount 10 |
| stages-2s-500.txt | the same with BatchTimeout 2s, MaxMessageCount 500 |
| overload.txt | the load generator at 250 transactions per second for 15 seconds |

## lab-01

`tools/capture/lab-01.sh` builds the Lab 1 port network from nothing with `network/network.sh`,
one step at a time, runs the lab scripts and removes the network. The peers ran with LevelDB
(`STATEDB=goleveldb`) because CouchDB is not available on the authoring machine; only the last
line of generate.txt shows it, and no other output depends on the state database.

| File | Produced by |
| --- | --- |
| design.txt, design-fail.txt | lab-01-port-network/scripts/check-design.sh (Listing L1.2) on network.json and examples/two-orderers.json |
| generate.txt, cas.txt, identities.txt, nodes.txt, deploy.txt | network/network.sh (Listing L1.3) with the matching command |
| check-msp.txt | network.sh check-msp customs (Listing L1.5) |
| channel.txt | network.sh channel (Listing L1.6) |
| status.txt | lab-01-port-network/scripts/status.sh (Listing L1.7) |
| smoke.txt | lab-01-port-network/scripts/smoke.sh (Listing L1.8) |
| resilience.txt | lab-01-port-network/scripts/resilience.sh (Listing L1.9) |
| add-org.txt | network.sh add-org forwarder (Listing L1.10) |
| forwarder.txt | lab-01-port-network/scripts/forwarder.sh (Listing L1.11) |
| failures.txt | lab-01-port-network/scripts/failures.sh (Listing L1.12) |

## lab-02

`tools/capture/lab-02.sh` builds the Lab 2 network from nothing with `network/network.sh`, runs
the lab scripts, upgrades the chaincode to version 1.1 with `upgrade/v1.1.patch`, then removes the
network and puts the chaincode and the network file back at version 1.0. As in Lab 1, the peers
ran with LevelDB.

| File | Produced by |
| --- | --- |
| tests.txt | npm run lint and npm run coverage in pharmatrace-chaincode |
| up.txt | network.sh lab-02-pharmatrace/network.json up |
| privacy.txt | lab-02-pharmatrace/scripts/privacy.sh (Listing L2.5) |
| scenario.txt | lab-02-pharmatrace/scripts/scenario.sh (Listing L2.6) |
| upgrade.txt | lab-02-pharmatrace/scripts/upgrade.sh (Listing L2.8) |
| recall-alert.txt | lab-02-pharmatrace/scripts/recall-alert.sh with the listener (Listings L2.9 and L2.10) |

## lab-03

`tools/capture/lab-03.sh` builds the Lab 3 network from nothing, enrolls the API users, starts the
integration service and runs the lab scripts against it; `tools/capture/lab-03-ui.js` takes the
history page screenshot (Figure L3.2) with Playwright. The wallet, secrets and service data are
deleted afterwards. As in Labs 1 and 2, the peers ran with LevelDB.

| File | Produced by |
| --- | --- |
| tests.txt | lint and coverage of parts-chaincode, then lint and unit tests of service |
| up.txt | network.sh lab-03-parts-integration/network.json up |
| enroll.txt | lab-03-parts-integration/scripts/enroll-users.sh (Listing L3.2) |
| api.txt | lab-03-parts-integration/scripts/api-demo.sh (Listing L3.6) |
| listener.txt | the service log's listener lines after api-demo.sh |
| restart.txt | lab-03-parts-integration/scripts/restart-demo.sh (Listing L3.8) |
| reconcile.txt | lab-03-parts-integration/scripts/reconcile.sh, using service/src/reconcile.ts (Listing L3.9) |
| load.txt | lab-03-parts-integration/scripts/load.sh, using service/src/load.ts |
| security.txt | lab-03-parts-integration/scripts/security-check.sh (Listing L3.10) |

## lab-04

`tools/capture/lab-04.sh` builds the Lab 4 network from nothing and runs the five parts of the drill
in order on the same network, then removes it. Part E deletes node data with the process runner's
`volume-rm`, which stands in for `docker volume rm`; node logs are read with the runner's `logs`,
which stands in for `docker compose logs`. As in Labs 1 to 3, the peers ran with LevelDB. The Raft
node IDs quoted in the text (2 before the failure, 5 after) come from the orderer0.importbank log of
the same run, which `down` deletes.

| File | Produced by |
| --- | --- |
| up.txt | network.sh lab-04-governance-drill/network.json up |
| policies.txt | lab-04-governance-drill/scripts/policies.sh (Listing L4.1) |
| vote.txt | lab-04-governance-drill/scripts/vote.sh (Listing L4.2) |
| rotation.txt | lab-04-governance-drill/scripts/rotation.sh (Listing L4.3) |
| ordering.txt | lab-04-governance-drill/scripts/ordering.sh (Listing L4.4) |
| recovery.txt | lab-04-governance-drill/scripts/recovery.sh (Listing L4.5) |

## appendix

Appendix A's outputs, from the scripts in `solutions/`. Each capture script states the network it
starts; all of them use the native harness, and the peers ran with LevelDB.

| File | Produced by |
| --- | --- |
| ex1-3-experiments.txt, ex2-1-msp-table.txt, ex2-2-config-answers.txt, ex2-3-mvcc-three.txt, ex2-4-policy-and.txt | tools/capture/appendix-ch01-02.sh |
| ex3-1-tests.txt, ex3-1-2-5-network.txt, ex3-3-leveldb.txt, ex3-5-deploy.txt | tools/capture/appendix-ch03.sh |
| ex3-4-add-org.txt, ex3-4-per-asset.txt | tools/capture/appendix-ch03-34.sh |
| ex4-2-create-raft20.txt, ex4-2-tick10.txt, ex4-2-tick20.txt, ex4-3-bft.txt | tools/capture/appendix-ch04.sh; timings vary from run to run |
| ex5-4-snapshot.txt, ex7-1-salt.txt, ex7-2-erasure.txt, ex7-3-revoke.txt | tools/capture/appendix-ch05-07.sh |
| ex5-2-add-org.txt, ex5-2-policy.txt, ex5-5-console.txt, ex5-5-network.log | tools/capture/appendix-ch05-gen.sh |
