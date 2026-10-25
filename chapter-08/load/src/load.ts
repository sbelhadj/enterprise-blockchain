/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing 8.2: an open-loop load generator. ImportBank's LC officer issues
 * letters of credit through the Fabric Gateway at fixed offered rates and the
 * script times each stage of every transaction: endorsement, the orderer's
 * acknowledgment, and the wait until the peer reports the commit.
 * Open loop means a new transaction starts on schedule whether or not earlier
 * ones have finished, as real clients do; a closed loop would hide queueing.
 *
 *   npm run load -- LABEL RATE[,RATE...] SECONDS
 *   npm run load -- "2s/10" 10,25,50 20
 *
 * One CSV row per rate is appended to results.csv.
 */
import * as grpc from '@grpc/grpc-js';
import {connect, Contract, hash, signers} from '@hyperledger/fabric-gateway';
import {createPrivateKey} from 'node:crypto';
import {promises as fs} from 'node:fs';
import * as path from 'node:path';

const ORG = path.resolve(__dirname, '../../../chapter-05/organizations/importbank');
const RESULTS = path.join(__dirname, '..', 'results.csv');

interface Timing {
    start: number; // when the transaction was due to start
    endorsed: number;
    ordered: number;
    committed: number;
    ok: boolean;
}

/** Runs one transaction and records when each stage finished. */
async function issue(
    contract: Contract, id: string, start: number,
): Promise<Timing> {
    const t: Timing = {start, endorsed: 0, ordered: 0, committed: 0, ok: false};
    const proposal = contract.newProposal('IssueLC', {
        arguments: [id, 'Load Test Applicant', 'Load Test Beneficiary',
            'ExportBankMSP', '100000', 'USD', '2027-12-31', 'Load test goods'],
    });
    const transaction = await proposal.endorse();
    t.endorsed = performance.now();
    const commit = await transaction.submit();
    t.ordered = performance.now();
    const status = await commit.getStatus();
    t.committed = performance.now();
    t.ok = status.successful;
    return t;
}

const pct = (sorted: number[], p: number): number =>
    sorted.length === 0 ? NaN : sorted[Math.min(sorted.length - 1,
        Math.floor((p / 100) * sorted.length))];
const mean = (xs: number[]): number => xs.reduce((a, b) => a + b, 0) / xs.length;

/** Offers RATE transactions per second for SECONDS seconds, then waits for all. */
async function step(
    contract: Contract, label: string, rate: number, seconds: number,
) {
    const total = rate * seconds;
    const tag = `${label.replace(/[^A-Za-z0-9]/g, '')}-${rate}-${Date.now() % 1e6}`;
    const runs: Promise<Timing | undefined>[] = [];
    const errors = new Map<string, number>();
    const t0 = performance.now();
    for (let i = 0; i < total; i++) {
        const due = t0 + (i * 1000) / rate;
        const wait = due - performance.now();
        if (wait > 1) {
            await new Promise((r) => setTimeout(r, wait));
        }
        runs.push(issue(contract, `LD-${tag}-${i}`, due).catch((e: Error) => {
            // count failures by message, without the transaction-specific part
            const msg = e.message.replace(/\(\w+\)/g, '').slice(0, 76);
            errors.set(msg, (errors.get(msg) ?? 0) + 1);
            return undefined;
        }));
    }
    const done = (await Promise.all(runs)).filter((t): t is Timing => !!t);
    const ok = done.filter((t) => t.ok);
    const lat = ok.map((t) => t.committed - t.start).sort((a, b) => a - b);
    const end = Math.max(...ok.map((t) => t.committed));
    const row = {
        label, offered: rate, sent: total, committed: ok.length,
        failed: total - ok.length,
        tps: ok.length / ((end - t0) / 1000),
        p50: pct(lat, 50), p95: pct(lat, 95),
        endorse: mean(ok.map((t) => t.endorsed - t.start)),
        order: mean(ok.map((t) => t.ordered - t.endorsed)),
        commit: mean(ok.map((t) => t.committed - t.ordered)),
    };
    const ms = (x: number) => x.toFixed(0).padStart(8);
    const cols = [row.p50, row.p95, row.endorse, row.order, row.commit].map(ms);
    console.log(label.padEnd(9) + String(rate).padStart(5) +
        row.tps.toFixed(1).padStart(7) + cols.join('') +
        String(row.failed).padStart(8));
    for (const [msg, n] of errors) {
        console.log(`  ${n} x ${msg}`);
    }
    return row;
}

async function main(): Promise<void> {
    const [label = 'run', rates = '10,25,50', seconds = '20'] =
        process.argv.slice(2);
    const user = path.join(ORG, 'lcofficer/msp');
    const [keyFile] = await fs.readdir(path.join(user, 'keystore'));
    const client = new grpc.Client(
        'localhost:8051',
        grpc.credentials.createSsl(
            await fs.readFile(path.join(ORG, 'msp/tlscacerts/tlsca.pem'))),
    );
    const gateway = connect({
        client,
        identity: {
            mspId: 'ImportBankMSP',
            credentials: await fs.readFile(path.join(user, 'signcerts/cert.pem')),
        },
        signer: signers.newPrivateKeySigner(
            createPrivateKey(
                await fs.readFile(path.join(user, 'keystore', keyFile)))),
        hash: hash.sha256,
        endorseOptions: () => ({deadline: Date.now() + 60_000}),
        submitOptions: () => ({deadline: Date.now() + 60_000}),
        commitStatusOptions: () => ({deadline: Date.now() + 120_000}),
    });
    try {
        const contract = gateway.getNetwork('lcchannel').getContract('lc');
        // times in milliseconds: latency percentiles, then the mean of each stage
        const head = ['p50', 'p95', 'endorse', 'order', 'commit'];
        console.log('setting'.padEnd(9) + 'rate'.padStart(5) + 'tps'.padStart(7) +
            head.map((h) => h.padStart(8)).join('') + 'failed'.padStart(8));
        for (const rate of rates.split(',').map(Number)) {
            const r = await step(contract, label, rate, Number(seconds));
            const header = Object.keys(r).join(',') + '\n';
            const exists = await fs.stat(RESULTS).then(() => true, () => false);
            await fs.appendFile(RESULTS, (exists ? '' : header) +
                Object.values(r).map((v) => typeof v === 'number' && !Number
                    .isInteger(v) ? v.toFixed(1) : v).join(',') + '\n');
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
