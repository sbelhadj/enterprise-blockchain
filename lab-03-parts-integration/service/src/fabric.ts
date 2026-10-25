/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L3.5: the service's connection to the ledger: one gRPC connection per
 * organization's peer, one Gateway per user, and a submit that retries MVCC
 * conflicts but never resubmits a transaction whose outcome it does not know.
 */
import * as grpc from '@grpc/grpc-js';
import {
    connect,
    Contract,
    Gateway,
    hash,
    Network,
    signers,
} from '@hyperledger/fabric-gateway';
import {peer} from '@hyperledger/fabric-protos';
import {createPrivateKey} from 'node:crypto';
import {promises as fs} from 'node:fs';
import {config, orgs} from './config';
import {Conflict, UnknownOutcome} from './errors';
import {ApiUser, loadIdentity} from './identity';

const codeName = (n: number): string =>
    Object.entries(peer.TxValidationCode).find(([, v]) => v === n)?.[0] ??
    String(n);

/**
 * Runs attempt() until it succeeds or fails with something other than a retryable
 * error, at most `tries` times. The waits double from `base` ms, plus a random
 * share of `base`, so that clients that collided once do not collide again.
 */
export async function withRetry<T>(
    attempt: () => Promise<T>,
    retryable: (e: unknown) => boolean,
    tries = 5,
    base = 250,
): Promise<{result: T; attempts: number}> {
    for (let i = 1; ; i++) {
        try {
            return {result: await attempt(), attempts: i};
        } catch (e) {
            if (i >= tries || !retryable(e)) {
                throw e;
            }
            const wait = base * 2 ** (i - 1) + Math.random() * base;
            await new Promise((r) => setTimeout(r, wait));
        }
    }
}

/**
 * Worth simulating again: an MVCC conflict, or endorsers that disagreed because
 * one had already committed a newer version of the key than the other.
 */
export function retryable(e: unknown): boolean {
    if (e instanceof Conflict) {
        return e.code === 'MVCC_READ_CONFLICT';
    }
    const err = e as {name?: string; details?: {message?: string}[]};
    return (
        err?.name === 'EndorseError' &&
        (err.details ?? []).some((d) =>
            /payloads do not match/i.test(d.message ?? ''),
        )
    );
}

export class Ledger {
    private clients = new Map<string, grpc.Client>();
    private gateways = new Map<string, Gateway>();

    async network(user: Pick<ApiUser, 'user' | 'org'>): Promise<Network> {
        let gw = this.gateways.get(user.user);
        if (!gw) {
            const org = orgs[user.org];
            const id = await loadIdentity(config.wallet, user.user);
            gw = connect({
                client: await this.client(user.org),
                identity: {mspId: org.msp, credentials: id.credentials},
                signer: signers.newPrivateKeySigner(
                    createPrivateKey(id.privateKeyPem),
                ),
                hash: hash.sha256,
                evaluateOptions: () => ({deadline: Date.now() + 5_000}),
                endorseOptions: () => ({deadline: Date.now() + 15_000}),
                submitOptions: () => ({deadline: Date.now() + 5_000}),
                commitStatusOptions: () => ({deadline: Date.now() + 60_000}),
            });
            this.gateways.set(user.user, gw);
        }
        return gw.getNetwork(config.channel);
    }

    async contract(user: Pick<ApiUser, 'user' | 'org'>): Promise<Contract> {
        return (await this.network(user)).getContract(config.chaincode);
    }

    async evaluate(user: ApiUser, fn: string, ...args: string[]): Promise<unknown> {
        const result = await (
            await this.contract(user)
        ).evaluateTransaction(fn, ...args);
        return JSON.parse(Buffer.from(result).toString()) as unknown;
    }

    /**
     * Endorse, submit and wait for the commit. An MVCC conflict means another
     * transaction changed what this one read: simulate again on the new state and
     * resubmit. A commit status that never arrives is different: the transaction
     * may yet commit, so it is reported, never resubmitted.
     */
    async submit(user: ApiUser, fn: string, ...args: string[]) {
        const contract = await this.contract(user);
        return withRetry(async () => {
            const tx = await contract.newProposal(fn, {arguments: args}).endorse();
            const commit = await tx.submit();
            let status;
            try {
                status = await commit.getStatus();
            } catch {
                throw new UnknownOutcome(tx.getTransactionId());
            }
            if (!status.successful) {
                throw new Conflict(status.transactionId, codeName(status.code));
            }
            return {
                txId: status.transactionId,
                block: Number(status.blockNumber),
            };
        }, retryable);
    }

    /** What happened to a transaction, from the system chaincode qscc. */
    async transactionStatus(user: ApiUser, txId: string) {
        const network = await this.network(user);
        try {
            const bytes = await network
                .getContract('qscc')
                .evaluateTransaction('GetTransactionByID', config.channel, txId);
            const tx = peer.ProcessedTransaction.deserializeBinary(bytes);
            return {txId, status: codeName(tx.getValidationcode())};
        } catch (e) {
            if ((e as {code?: number}).code === grpc.status.UNKNOWN) {
                return {txId, status: 'NOT_FOUND'};
            }
            throw e;
        }
    }

    private async client(org: string): Promise<grpc.Client> {
        let c = this.clients.get(org);
        if (!c) {
            const tlsRoot = await fs.readFile(orgs[org].tlsRoot);
            c = new grpc.Client(
                orgs[org].peer,
                grpc.credentials.createSsl(tlsRoot),
            );
            this.clients.set(org, c);
        }
        return c;
    }

    close(): void {
        this.gateways.forEach((g) => g.close());
        this.clients.forEach((c) => c.close());
    }
}
