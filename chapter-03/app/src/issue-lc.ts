/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing 3.20: ImportBank's LC officer issues an LC through the Fabric Gateway.
 * Run from anywhere after Listing 3.14:  npm run issue -- LC-2026-001
 */
import * as grpc from '@grpc/grpc-js';
import {connect, hash, Identity, Signer, signers} from '@hyperledger/fabric-gateway';
import {createPrivateKey} from 'node:crypto';
import {promises as fs} from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

const samples = process.env.FABRIC_SAMPLES ?? path.join(os.homedir(), 'fabric-samples');
const org2 = path.join(
    samples,
    'test-network/organizations/peerOrganizations/org2.example.com',
);
const user = path.join(org2, 'users/lcofficer@org2.example.com/msp');

async function identity(): Promise<Identity> {
    const credentials = await fs.readFile(path.join(user, 'signcerts/cert.pem'));
    return {mspId: 'Org2MSP', credentials};
}

async function signer(): Promise<Signer> {
    const keyDir = path.join(user, 'keystore');
    const [keyFile] = await fs.readdir(keyDir);
    const privateKey = createPrivateKey(await fs.readFile(path.join(keyDir, keyFile)));
    return signers.newPrivateKeySigner(privateKey);
}

async function main(): Promise<void> {
    const id = process.argv[2] ?? 'LC-2026-001';
    // The client may use its own clock: it only chooses an input. The chaincode never does.
    const expiry = new Date(Date.now() + 180 * 24 * 3600 * 1000).toISOString().slice(0, 10);

    // One TLS connection to ImportBank's own gateway peer
    const tlsRoot = await fs.readFile(
        path.join(org2, 'tlsca/tlsca.org2.example.com-cert.pem'),
    );
    const client = new grpc.Client('localhost:9051', grpc.credentials.createSsl(tlsRoot), {
        'grpc.ssl_target_name_override': 'peer0.org2.example.com',
    });
    const gateway = connect({
        client,
        identity: await identity(),
        signer: await signer(),
        hash: hash.sha256,
        evaluateOptions: () => ({deadline: Date.now() + 5000}),
        endorseOptions: () => ({deadline: Date.now() + 15000}),
        submitOptions: () => ({deadline: Date.now() + 5000}),
        commitStatusOptions: () => ({deadline: Date.now() + 60000}),
    });

    try {
        const contract = gateway.getNetwork('mychannel').getContract('lc');

        // Submit: the gateway finds the endorsers the policy needs, collects endorsements,
        // sends the transaction to the ordering service and lets us wait for the commit
        const submitted = await contract.submitAsync('IssueLC', {
            arguments: [
                id,
                'Tunis Olive Imports',
                'Sfax Olive Oil Co',
                'Org1MSP',
                '125000000',
                'EUR',
                expiry,
                '20 t extra virgin olive oil',
            ],
        });
        console.log(`transaction ${submitted.getTransactionId()} submitted`);
        const status = await submitted.getStatus();
        const outcome = status.successful ? 'VALID' : String(status.code);
        console.log(`committed in block ${status.blockNumber} with status ${outcome}`);

        // Evaluate: one peer runs the query; nothing is ordered or committed
        const lc = await contract.evaluateTransaction('ReadLC', id);
        console.log(JSON.stringify(JSON.parse(Buffer.from(lc).toString('utf8')), null, 2));
    } finally {
        gateway.close();
        client.close();
    }
}

main().catch((err: unknown) => {
    console.error(err);
    process.exitCode = 1;
});
