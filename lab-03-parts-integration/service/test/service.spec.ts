/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Unit tests: everything that can be checked without a network. The scripts in
 * ../scripts test the same service against the running Fabric network.
 */
import {expect} from 'chai';
import {AddressInfo} from 'node:net';
import {createApp, LedgerPort} from '../src/api';
import {MaintenanceDb} from '../src/db';
import {Conflict, toHttp, UnknownOutcome} from '../src/errors';
import {retryable, withRetry} from '../src/fabric';
import {ApiUser, authenticate, sha256} from '../src/identity';
import {compare} from '../src/reconcile';

const KEY = 'k'.repeat(32);
const amel: ApiUser = {user: 'amel', org: 'airline', keyHash: sha256(KEY)};
const endorseError = (message: string) => ({
    name: 'EndorseError',
    message: 'endorse failed',
    details: [{message: `chaincode response 500, ${message}`}],
});

describe('errors', () => {
    it('maps chaincode refusals to client errors', () => {
        const status = (m: string) => toHttp(endorseError(m)).status;
        expect(status('AirlineMSP may not record REPAIR')).to.equal(403);
        expect(status('part ESN-9 does not exist')).to.equal(404);
        expect(status('part ESN-1 already exists')).to.equal(409);
        expect(status('part ESN-1 is SERVICEABLE; REMOVE is not allowed')).to.equal(
            409,
        );
        expect(status('invalid serial "x"')).to.equal(400);
        expect(status('something else')).to.equal(502);
        expect(toHttp(endorseError('invalid serial "x"')).body.detail).to.equal(
            'invalid serial "x"',
        );
    });

    it('reports unknown outcomes, conflicts and outages distinctly', () => {
        expect(toHttp(new UnknownOutcome('t1'))).to.deep.include({status: 202});
        expect(
            toHttp(new Conflict('t2', 'MVCC_READ_CONFLICT')).body.error,
        ).to.equal('MVCC_READ_CONFLICT');
        expect(toHttp({name: 'SubmitError', message: 'x'}).status).to.equal(503);
        const query = {
            name: 'GatewayError',
            message:
                '2 UNKNOWN: evaluate call to endorser returned error: ' +
                'chaincode response 500, part ESN-9 does not exist',
        };
        expect(toHttp(query)).to.deep.include({status: 404});
        expect(
            toHttp({name: 'GatewayError', message: '14 UNAVAILABLE'}).status,
        ).to.equal(503);
        expect(toHttp(new Error('boom')).status).to.equal(500);
        expect(toHttp(undefined).status).to.equal(500);
        expect(
            toHttp({name: 'EndorseError', message: 'no details'}).status,
        ).to.equal(502);
    });
});

describe('identity', () => {
    it('accepts the right bearer key and nothing else', () => {
        expect(authenticate([amel], `Bearer ${KEY}`)).to.equal(amel);
        expect(authenticate([amel], `Bearer ${'x'.repeat(32)}`)).to.equal(
            undefined,
        );
        expect(authenticate([amel], KEY)).to.equal(undefined);
        expect(authenticate([amel])).to.equal(undefined);
    });
});

describe('withRetry', () => {
    it('retries retryable failures and stops at the limit', async () => {
        let n = 0;
        const r = await withRetry(
            async () => {
                if (++n < 3) throw new Error('again');
                return 'done';
            },
            () => true,
            3,
            1,
        );
        expect(r).to.deep.equal({result: 'done', attempts: 3});
        n = 0;
        let error: unknown;
        try {
            await withRetry(
                async () => {
                    n++;
                    throw new Error('never');
                },
                () => true,
                2,
                1,
            );
        } catch (e) {
            error = e;
        }
        expect((error as Error).message).to.equal('never');
        expect(n).to.equal(2);
    });

    it('does not retry other failures', async () => {
        let n = 0;
        try {
            await withRetry(
                async () => {
                    n++;
                    throw new Error('no');
                },
                () => false,
            );
        } catch {
            // expected
        }
        expect(n).to.equal(1);
    });
});

describe('retryable', () => {
    it('retries MVCC conflicts and endorsers that disagreed, nothing else', () => {
        expect(retryable(new Conflict('t', 'MVCC_READ_CONFLICT'))).to.equal(true);
        expect(retryable(new Conflict('t', 'ENDORSEMENT_POLICY_FAILURE'))).to.equal(
            false,
        );
        const mismatch = {
            name: 'EndorseError',
            details: [{message: 'ProposalResponsePayloads do not match'}],
        };
        expect(retryable(mismatch)).to.equal(true);
        expect(retryable({name: 'EndorseError', details: [{}]})).to.equal(false);
        expect(retryable({name: 'EndorseError'})).to.equal(false);
        expect(retryable(new UnknownOutcome('t'))).to.equal(false);
        expect(retryable(undefined)).to.equal(false);
    });
});

describe('maintenance database', () => {
    const event = (txId: string, status: string, cycles = 0) => ({
        txId,
        block: 5n,
        type: 'X',
        part: {
            serial: 'ESN-1',
            partNumber: 'P',
            status,
            aircraft: '',
            position: '',
            cycles,
        },
    });

    it('applies each transaction once', () => {
        const db = new MaintenanceDb(':memory:');
        expect(db.apply(event('t1', 'SERVICEABLE'))).to.equal(true);
        expect(db.apply(event('t1', 'SERVICEABLE'))).to.equal(false);
        expect(db.apply(event('t2', 'INSTALLED', 3))).to.equal(true);
        expect(db.parts()).to.deep.include({
            serial: 'ESN-1',
            status: 'INSTALLED',
            cycles: 3,
            last_tx: 't2',
            part_number: 'P',
            aircraft: '',
            position: '',
        });
        db.overwrite({...db.parts()[0], status: 'SCRAPPED'});
        expect(db.parts()[0].status).to.equal('SCRAPPED');
        db.close();
    });

    it('rolls back a failed update', () => {
        const db = new MaintenanceDb(':memory:');
        const bad = event('t3', 'X');
        (bad.part as {partNumber: unknown}).partNumber = null; // NOT NULL column
        expect(() => db.apply(bad)).to.throw();
        expect(db.apply(event('t3', 'SERVICEABLE'))).to.equal(true);
        db.close();
    });
});

describe('reconciliation', () => {
    it('lists every difference between database and ledger', () => {
        const row = {
            serial: 'A',
            part_number: 'P',
            status: 'INSTALLED',
            aircraft: 'TS-IMW',
            position: 'P1',
            cycles: 3,
            last_tx: 't',
        };
        const part = {
            serial: 'A',
            partNumber: 'P',
            status: 'INSTALLED',
            aircraft: 'TS-IMW',
            position: 'P1',
            cycles: 4,
        };
        const r = compare(
            [row, {...row, serial: 'Z'}],
            [part, {...part, serial: 'B'}],
        );
        expect(r.checked).to.equal(2);
        expect(r.differences).to.deep.equal([
            'A: cycles is 3 here, 4 on the ledger',
            'B: on the ledger, missing in the database',
            'Z: in the database, not on the ledger',
        ]);
    });
});

describe('api', () => {
    const calls: string[][] = [];
    const ledger: LedgerPort = {
        evaluate: async (_u, fn, ...args) => {
            if (args[0] === 'ESN-9')
                throw endorseError('part ESN-9 does not exist');
            return {fn, args};
        },
        submit: async (u, fn, ...args) => {
            calls.push([u.user, fn, ...args]);
            return {result: {txId: 'tx1', block: 7}, attempts: 1};
        },
        transactionStatus: async (_u, txId) => ({txId, status: 'VALID'}),
    };
    let base = '';
    let close = () => {};

    before(async () => {
        const server = createApp(ledger, [amel]).listen(0, '127.0.0.1');
        await new Promise((r) => server.once('listening', r));
        base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
        close = () => server.close();
    });
    after(() => close());

    const call = async (
        path: string,
        method = 'GET',
        body?: unknown,
        key = KEY,
    ) => {
        const res = await fetch(base + path, {
            method,
            headers: {
                authorization: `Bearer ${key}`,
                'content-type': 'application/json',
            },
            body: body === undefined ? undefined : JSON.stringify(body),
        });
        return {
            status: res.status,
            body: (await res.json()) as Record<string, unknown>,
        };
    };

    it('refuses requests without a valid key', async () => {
        expect(
            (await call('/parts/ESN-1', 'GET', undefined, 'nope')).status,
        ).to.equal(401);
    });

    it('reads, submits under the caller and maps errors', async () => {
        expect((await call('/parts/ESN-1')).body).to.deep.equal({
            fn: 'ReadPart',
            args: ['ESN-1'],
        });
        expect((await call('/parts/ESN-1/history')).body.fn).to.equal('GetHistory');
        expect((await call('/parts/ESN-9')).status).to.equal(404);
        const r = await call('/parts', 'POST', {
            serial: 'ESN-2',
            partNumber: 'P',
            description: 'd',
            certHash: 'h',
        });
        expect(r).to.deep.equal({
            status: 201,
            body: {txId: 'tx1', block: 7, attempts: 1},
        });
        await call('/parts/ESN-2/events', 'POST', {
            type: 'INSTALL',
            aircraft: 'TS-IMW',
        });
        await call('/parts/ESN-2/cycles', 'POST', {cycles: 2});
        await call('/parts/ESN-2/cycles', 'POST', {});
        expect(calls).to.deep.equal([
            ['amel', 'RegisterPart', 'ESN-2', 'P', 'd', 'h'],
            ['amel', 'RecordEvent', 'ESN-2', 'INSTALL', 'TS-IMW', '', ''],
            ['amel', 'RecordCycles', 'ESN-2', '2'],
            ['amel', 'RecordCycles', 'ESN-2', ''],
        ]);
        expect((await call('/transactions/tx1')).body.status).to.equal('VALID');
        expect((await call('/maintenance/parts')).body).to.deep.equal([]);
    });

    it('serves the history page without a key', async () => {
        const res = await fetch(`${base}/`);
        expect(res.status).to.equal(200);
        expect(await res.text()).to.contain('<title>Part history</title>');
    });
});
