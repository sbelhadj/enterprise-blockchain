/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing 7.9: an audit log from the ledger. Reads every block of lcchannel from
 * ExportBank's peer, writes one JSON line per transaction to audit.jsonl and
 * prints a summary: who submitted what, when, and whether the peer accepted it.
 * A SIEM can ingest the file.
 * Run from chapter-07/audit after npm ci and npm run build:  npm run audit
 */
import * as grpc from '@grpc/grpc-js';
import {connect, hash, signers} from '@hyperledger/fabric-gateway';
import {common, msp, peer} from '@hyperledger/fabric-protos';
import {createPrivateKey} from 'node:crypto';
import {promises as fs} from 'node:fs';
import * as path from 'node:path';

const ORG = path.resolve(__dirname, '../../../chapter-05/organizations/exportbank');
const CHANNEL = 'lcchannel';
const codes = Object.fromEntries(
    Object.entries(peer.TxValidationCode).map(([name, n]) => [n, name]),
);

interface AuditRecord {
    block: number;
    txId: string;
    time: string;
    type: string;
    creator: string;
    chaincode?: string;
    function?: string;
    validation: string;
}

function records(block: common.Block): AuditRecord[] {
    const number = Number(block.getHeader()!.getNumber());
    // The peer stores one validation code per transaction in metadata slot 2
    const filter = block.getMetadata()!.getMetadataList_asU8()[
        common.BlockMetadataIndex.TRANSACTIONS_FILTER
    ];
    return block
        .getData()!
        .getDataList_asU8()
        .map((bytes, i) => {
            const payload = common.Payload.deserializeBinary(
                common.Envelope.deserializeBinary(bytes).getPayload_asU8(),
            );
            const header = payload.getHeader()!;
            const channelHeader = common.ChannelHeader.deserializeBinary(
                header.getChannelHeader_asU8(),
            );
            const creator = msp.SerializedIdentity.deserializeBinary(
                common.SignatureHeader.deserializeBinary(
                    header.getSignatureHeader_asU8(),
                ).getCreator_asU8(),
            );
            const r: AuditRecord = {
                block: number,
                txId: channelHeader.getTxId(),
                time: channelHeader.getTimestamp()!.toDate().toISOString(),
                type:
                    channelHeader.getType() === common.HeaderType.CONFIG
                        ? 'config'
                        : 'transaction',
                creator: creator.getMspid(),
                validation: codes[filter[i]] ?? String(filter[i]),
            };
            if (
                channelHeader.getType() === common.HeaderType.ENDORSER_TRANSACTION
            ) {
                const action = peer.Transaction.deserializeBinary(
                    payload.getData_asU8(),
                )
                    .getActionsList()[0]
                    .getPayload_asU8();
                const proposal = peer.ChaincodeProposalPayload.deserializeBinary(
                    peer.ChaincodeActionPayload.deserializeBinary(
                        action,
                    ).getChaincodeProposalPayload_asU8(),
                );
                const spec = peer.ChaincodeInvocationSpec.deserializeBinary(
                    proposal.getInput_asU8(),
                ).getChaincodeSpec()!;
                r.chaincode = spec.getChaincodeId()!.getName();
                // Arguments are on the ledger; only the function name is logged
                r.function = Buffer.from(
                    spec.getInput()!.getArgsList_asU8()[0],
                ).toString();
            }
            return r;
        });
}

async function main(): Promise<void> {
    const user = path.join(ORG, 'user1/msp');
    const [keyFile] = await fs.readdir(path.join(user, 'keystore'));
    const client = new grpc.Client(
        'localhost:7051',
        grpc.credentials.createSsl(
            await fs.readFile(path.join(ORG, 'msp/tlscacerts/tlsca.pem')),
        ),
    );
    const gateway = connect({
        client,
        identity: {
            mspId: 'ExportBankMSP',
            credentials: await fs.readFile(path.join(user, 'signcerts/cert.pem')),
        },
        signer: signers.newPrivateKeySigner(
            createPrivateKey(
                await fs.readFile(path.join(user, 'keystore', keyFile)),
            ),
        ),
        hash: hash.sha256,
    });
    try {
        const network = gateway.getNetwork(CHANNEL);
        const info = common.BlockchainInfo.deserializeBinary(
            await network
                .getContract('qscc')
                .evaluateTransaction('GetChainInfo', CHANNEL),
        );
        const height = BigInt(info.getHeight());
        const out = await fs.open(path.join(__dirname, '..', 'audit.jsonl'), 'w');
        const events = await network.getBlockEvents({startBlock: 0n});
        const all: AuditRecord[] = [];
        try {
            for await (const block of events) {
                for (const r of records(block)) {
                    all.push(r);
                    await out.write(JSON.stringify(r) + '\n');
                }
                if (BigInt(block.getHeader()!.getNumber()) === height - 1n) {
                    break;
                }
            }
        } finally {
            events.close();
            await out.close();
        }
        const last = height - 1n;
        console.log(`${all.length} transactions up to block ${last}; the last 6:`);
        for (const r of all.slice(-6)) {
            // the full records are in audit.jsonl
            const what = r.chaincode ? `${r.chaincode}.${r.function}` : r.type;
            const time = r.time.slice(11, 19);
            const row = [r.block, time, r.txId.slice(0, 8), r.creator];
            console.log(`  block ${row.join(' ')} ${what} ${r.validation}`);
        }
        const rejected = all.filter((r) => r.validation !== 'VALID');
        console.log(`rejected: ${rejected.length}`);
        for (const r of rejected) {
            console.log(
                `  block ${r.block} ${r.creator} ${r.function ?? r.type}: ` +
                    r.validation,
            );
        }
    } finally {
        gateway.close();
        client.close();
    }
}

main().catch((err: unknown) => {
    console.error(err);
    process.exitCode = 1;
});
