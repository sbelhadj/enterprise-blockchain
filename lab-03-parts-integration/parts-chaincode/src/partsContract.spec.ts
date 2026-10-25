/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {expect} from 'chai';
import {contracts, PartsContract} from './index';
import {Part, Status} from './part';
import {context, FakeIdentity, FakeStub} from './test-support/fakes';

const maker = new FakeIdentity('PartsMakerMSP');
const mro = new FakeIdentity('MROMSP');
const airline = new FakeIdentity('AirlineMSP');
const H1 = 'a'.repeat(64);
const H2 = 'b'.repeat(64);

describe('PartsContract', () => {
    let c: PartsContract;
    let stub: FakeStub;
    const ctx = (who: FakeIdentity) => context(stub, who);
    const register = (serial = 'ESN-1001', who = maker) =>
        c.RegisterPart(ctx(who), serial, 'HPT-BLADE-7', 'HP turbine blade', H1);
    const event = (type: string, who = mro, aircraft = '', pos = '', doc = '') =>
        c.RecordEvent(ctx(who), 'ESN-1001', type, aircraft, pos, doc);
    const read = async (serial = 'ESN-1001') =>
        JSON.parse(await c.ReadPart(ctx(airline), serial)) as Part;
    const fails = async (p: Promise<unknown>, message: RegExp) => {
        let error: Error | undefined;
        try {
            await p;
        } catch (e) {
            error = e as Error;
        }
        expect(error, 'expected an error').to.be.instanceOf(Error);
        expect((error as Error).message).to.match(message);
    };

    beforeEach(() => {
        c = new PartsContract();
        stub = new FakeStub();
    });

    it('is the exported contract', () => {
        expect(contracts).to.deep.equal([PartsContract]);
    });

    it('registers a serviceable part and emits an event', async () => {
        await register();
        expect(await read()).to.include({
            status: Status.SERVICEABLE,
            lastDocHash: H1,
            updatedBy: 'PartsMakerMSP',
            cycles: 0,
        });
        const e = JSON.parse(stub.events[0].payload) as {type: string; part: Part};
        expect(stub.events[0].name).to.equal('PartEvent');
        expect(e.type).to.equal('REGISTER');
        expect(e.part.serial).to.equal('ESN-1001');
    });

    it('validates registration', async () => {
        await fails(register('ESN-1001', mro), /MROMSP may not register/);
        await fails(register('bad serial'), /invalid serial/);
        await fails(
            c.RegisterPart(ctx(maker), 'ESN-1', ' ', 'x', H1),
            /partNumber must be 1 to 32/,
        );
        await fails(
            c.RegisterPart(ctx(maker), 'ESN-1', 'P', 'x'.repeat(129), H1),
            /description must be/,
        );
        await fails(
            c.RegisterPart(ctx(maker), 'ESN-1', 'P', 'd', 'ABC'),
            /document hash must be/,
        );
        await register();
        await fails(register(), /already exists/);
    });

    it('runs install, cycles, removal, repair and reinstallation', async () => {
        await register();
        await event('INSTALL', airline, 'TS-IMW', 'ENG1-HPT-STG1');
        expect(await read()).to.include({
            aircraft: 'TS-IMW',
            status: Status.INSTALLED,
        });
        await c.RecordCycles(ctx(airline), 'ESN-1001', '3');
        await c.RecordCycles(ctx(airline), 'ESN-1001', '2');
        expect((await read()).cycles).to.equal(5);
        await event('REMOVE', mro);
        expect(await read()).to.include({
            aircraft: '',
            status: Status.UNSERVICEABLE,
        });
        await event('REPAIR', mro, '', '', H2);
        expect(await read()).to.include({
            status: Status.SERVICEABLE,
            lastDocHash: H2,
        });
        await event('INSTALL', mro, 'TS-IMX', 'ENG2-HPT-STG1');
        const h = JSON.parse(await c.GetHistory(ctx(mro), 'ESN-1001')) as {
            status: string;
        }[];
        expect(h.map((x) => x.status)).to.deep.equal([
            'SERVICEABLE',
            'INSTALLED',
            'INSTALLED',
            'INSTALLED',
            'UNSERVICEABLE',
            'SERVICEABLE',
            'INSTALLED',
        ]);
    });

    it('scraps an unserviceable part for good', async () => {
        await register();
        await event('INSTALL', airline, 'TS-IMW', 'P1');
        await event('REMOVE', airline);
        await event('SCRAP', airline);
        expect((await read()).status).to.equal(Status.SCRAPPED);
        await fails(event('REPAIR', mro, '', '', H2), /SCRAPPED; REPAIR is not/);
    });

    it('refuses unknown events, wrong organizations and bad input', async () => {
        await register();
        await fails(event('FLY'), /unknown event type "FLY"/);
        await fails(event('constructor'), /unknown event type/);
        await fails(event('REPAIR', airline), /AirlineMSP may not record REPAIR/);
        await fails(event('REMOVE'), /SERVICEABLE; REMOVE is not allowed/);
        await fails(event('INSTALL', airline, 'not a reg!', 'P1'), /registration/);
        await fails(event('INSTALL', airline, 'TS-IMW', ''), /position must be/);
        await event('INSTALL', airline, 'TS-IMW', 'P1');
        await event('REMOVE', airline);
        await fails(event('REPAIR', mro, '', '', 'x'), /document hash/);
        await fails(
            c.RecordEvent(ctx(mro), 'ESN-9', 'REMOVE', '', '', ''),
            /part ESN-9 does not exist/,
        );
    });

    it('records cycles from the airline only, for installed parts', async () => {
        await register();
        await fails(
            c.RecordCycles(ctx(mro), 'ESN-1001', '1'),
            /may not record cycles/,
        );
        await fails(
            c.RecordCycles(ctx(airline), 'ESN-1001', '1'),
            /only installed/,
        );
        for (const bad of ['0', '101', '1.5', 'x']) {
            await fails(
                c.RecordCycles(ctx(airline), 'ESN-1001', bad),
                /whole number/,
            );
        }
    });

    it('lists every part for reconciliation', async () => {
        await register('ESN-1002');
        await register('ESN-1001');
        const parts = JSON.parse(await c.ListParts(ctx(airline))) as Part[];
        expect(parts.map((p) => p.serial)).to.deep.equal(['ESN-1001', 'ESN-1002']);
        await fails(c.GetHistory(ctx(airline), '?'), /invalid serial/);
    });
});
