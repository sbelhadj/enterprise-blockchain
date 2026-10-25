/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L2.9: a recall alert. Listens to PharmaTrace chaincode events through the
 * regulator's peer and prints an alert for every BatchRecalled event. In
 * production, the alert would page the pharmacovigilance team and notify every
 * pharmacy holding the batch; Lab 3 adds checkpoints so a restart misses nothing.
 *   npm start [ALERTS]      stop after ALERTS alerts (default: run until Ctrl+C)
 */
import * as grpc from '@grpc/grpc-js';
import {connect, hash, signers} from '@hyperledger/fabric-gateway';
import {createPrivateKey} from 'node:crypto';
import {promises as fs} from 'node:fs';
import * as path from 'node:path';

const ORG = path.resolve(__dirname, '../../build/organizations/regulator');

interface Recall {
    id: string;
    product: string;
    holder: string;
    recallReason: string;
    updatedBy: string;
}

async function main(): Promise<void> {
    const max = Number(process.argv[2] ?? Infinity);
    const user = path.join(ORG, 'user1/msp');
    const [keyFile] = await fs.readdir(path.join(user, 'keystore'));
    const client = new grpc.Client(
        'localhost:10051',
        grpc.credentials.createSsl(
            await fs.readFile(path.join(ORG, 'msp/tlscacerts/tlsca.pem')),
        ),
    );
    const gateway = connect({
        client,
        identity: {
            mspId: 'RegulatorMSP',
            credentials: await fs.readFile(path.join(user, 'signcerts/cert.pem')),
        },
        signer: signers.newPrivateKeySigner(
            createPrivateKey(
                await fs.readFile(path.join(user, 'keystore', keyFile)),
            ),
        ),
        hash: hash.sha256,
    });
    const events = await gateway
        .getNetwork('pharmachannel')
        .getChaincodeEvents('pharmatrace');
    console.log('listening for recalls on pharmachannel');
    let alerts = 0;
    try {
        for await (const e of events) {
            if (e.eventName !== 'BatchRecalled') {
                continue; // every other change to a batch
            }
            const r = JSON.parse(Buffer.from(e.payload).toString()) as Recall;
            console.log(`ALERT recall of ${r.id} (${r.product}) by ${r.updatedBy}`);
            console.log(`  reason: ${r.recallReason}`);
            console.log(`  stock held by ${r.holder}; block ${e.blockNumber},` +
                ` transaction ${e.transactionId.slice(0, 16)}...`);
            if (++alerts >= max) {
                break;
            }
        }
    } finally {
        events.close();
        gateway.close();
        client.close();
    }
}

main().catch((err: unknown) => {
    console.error(err);
    process.exitCode = 1;
});
