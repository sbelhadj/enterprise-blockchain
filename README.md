# Enterprise Blockchain Revolution: companion repository

Code for *Enterprise Blockchain Revolution: Harnessing Hyperledger Fabric for Business
Transformation* (The Blockchain Professional Series, Book 4) by Sami BELHADJ.

Every listing in the book comes from this repository and every output printed in the book comes
from `captured-outputs/`. If the book and the code disagree, the code is right.

| Folder | Content | Status |
|--------|---------|--------|
| `tools/` | `fetch-fabric.sh` downloads the pinned Fabric 3.1.5 and Fabric CA 1.5.22 binaries | done |
| `network/` | The network generator: `network.sh NETWORK.json up` builds a Fabric CA, Raft, CouchDB and CCaaS network from a network file (Lab 1, reused by Labs 2 to 4) | done |
| `chapter-01/` to `chapter-08/` | Chapter code; exercise solutions are in `solutions/` | done |
| `lab-01-port-network/` | Lab 1: a port community network (logistics) | done |
| `lab-02-pharmatrace/` | Lab 2: pharmaceutical batch traceability (healthcare) | done |
| `lab-03-parts-integration/` | Lab 3: aircraft parts records and a maintenance system (industrial) | done |
| `lab-04-governance-drill/` | Lab 4: governance and recovery drill (finance) | done |
| `solutions/` | Appendix A: solutions to the chapter exercises that need code or a run | done |
| `captured-outputs/` | Real runs used in the book | done |
| `docs/` | Working notes, including what it takes to run Fabric without Docker | started |

Toolchain pins are in `VERSIONS.md`.

## Quick start

```bash
./tools/fetch-fabric.sh
export PATH="$PWD/fabric/bin:$PATH"
peer version
```

You need Linux, macOS or Windows 11 with WSL2, Node.js 22, Docker Engine with Compose v2, jq and
OpenSSL. No testnet, faucet or cloud account is needed: every exercise runs on your machine.
