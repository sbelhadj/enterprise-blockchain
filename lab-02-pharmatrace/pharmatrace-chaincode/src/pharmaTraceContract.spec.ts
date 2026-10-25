/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {expect} from 'chai';
import {Batch, Status, validGtin} from './batch';
import {contracts, PharmaTraceContract} from './index';
import {context, FakeIdentity, FakeStub} from './test-support/fakes';

const mfr = new FakeIdentity('ManufacturerMSP');
const dist = new FakeIdentity('DistributorMSP');
const pharmacy = new FakeIdentity('PharmacyMSP');
const regulator = new FakeIdentity('RegulatorMSP');
const GTIN = '00012345600012';

describe('PharmaTraceContract', () => {
    let c: PharmaTraceContract;
    let stub: FakeStub;
    const ctx = (who: FakeIdentity) => context(stub, who);
    const produce = (id = 'B1', serials = '["S1","S2"]', who = mfr, gtin = GTIN) =>
        c.ProduceBatch(ctx(who), id, gtin, 'Amoxicillin 500 mg', serials);
    const read = async (id = 'B1') =>
        JSON.parse(await c.ReadBatch(ctx(mfr), id)) as Batch;
    const verify = async (serial: string) =>
        (
            JSON.parse(await c.VerifySerial(ctx(pharmacy), serial)) as {
                verdict: string;
            }
        ).verdict;
    const policyOf = (id = 'B1') =>
        Buffer.from(stub.validationParameters.get(id) as Uint8Array).toString(
            'latin1',
        );
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
    /** Produce B1 and move it to the pharmacy. */
    const toPharmacy = async () => {
        await produce();
        await c.ShipBatch(ctx(mfr), 'B1', 'DistributorMSP');
        await c.ReceiveBatch(ctx(dist), 'B1');
        await c.ShipBatch(ctx(dist), 'B1', 'PharmacyMSP');
        await c.ReceiveBatch(ctx(pharmacy), 'B1');
    };

    beforeEach(() => {
        c = new PharmaTraceContract();
        stub = new FakeStub();
    });

    it('is the exported contract', () => {
        expect(contracts).to.deep.equal([PharmaTraceContract]);
    });

    it('checks GS1 check digits', () => {
        expect(validGtin(GTIN)).to.equal(true);
        expect(validGtin('00012345600013')).to.equal(false);
        expect(validGtin('1234')).to.equal(false);
    });

    it('produces a batch; the maker holds it', async () => {
        await produce();
        const b = await read();
        expect(b).to.include({status: Status.PRODUCED, holder: 'ManufacturerMSP'});
        expect(b.updatedAt).to.equal('2026-10-24T10:00:00.000Z');
        expect(policyOf())
            .to.contain('ManufacturerMSP')
            .and.not.contain('Distributor');
        expect(await verify('S1')).to.equal('OK');
        expect(stub.events[0].name).to.equal('BatchUpdated');
    });

    it('validates production input and caller', async () => {
        await fails(
            produce('B1', '["S1"]', dist),
            /DistributorMSP may not produce/,
        );
        await fails(produce('bad id'), /invalid batch id/);
        await fails(produce('B1', '["S1"]', mfr, '00012345600013'), /invalid GTIN/);
        await fails(
            c.ProduceBatch(ctx(mfr), 'B1', GTIN, ' ', '["S1"]'),
            /product must be/,
        );
        await fails(produce('B1', 'not json'), /JSON array of strings/);
        await fails(produce('B1', '{}'), /1 to 100 unique/);
        await fails(produce('B1', '[]'), /1 to 100 unique/);
        await fails(produce('B1', '["S1","S1"]'), /1 to 100 unique/);
        await fails(produce('B1', '["S-1"]'), /1 to 100 unique/);
        await fails(
            produce('B1', JSON.stringify([...Array(101).keys()].map(String))),
            /1 to 100/,
        );
    });

    it('refuses a duplicate batch or a serial already registered', async () => {
        await produce();
        await fails(produce('B1', '["S9"]'), /batch B1 already exists/);
        await fails(
            produce('B2', '["S9","S2"]'),
            /serial S2 is already registered/,
        );
    });

    it('moves custody with both parties named in the key policy', async () => {
        await produce();
        await c.ShipBatch(ctx(mfr), 'B1', 'DistributorMSP');
        expect(await read()).to.include({
            status: Status.SHIPPED,
            shippedTo: 'DistributorMSP',
        });
        expect(policyOf())
            .to.contain('ManufacturerMSP')
            .and.contain('DistributorMSP');
        await c.ReceiveBatch(ctx(dist), 'B1');
        expect(await read()).to.include({holder: 'DistributorMSP', shippedTo: ''});
        expect(policyOf())
            .to.contain('DistributorMSP')
            .and.not.contain('Manufacturer');
    });

    it('refuses bad shipments and receipts', async () => {
        await produce();
        await fails(
            c.ShipBatch(ctx(dist), 'B1', 'PharmacyMSP'),
            /may not ship this/,
        );
        await fails(
            c.ShipBatch(ctx(mfr), 'B1', 'PharmacyMSP'),
            /may not ship to PharmacyMSP/,
        );
        await c.ShipBatch(ctx(mfr), 'B1', 'DistributorMSP');
        await fails(
            c.ShipBatch(ctx(mfr), 'B1', 'DistributorMSP'),
            /SHIPPED and cannot/,
        );
        await fails(c.ReceiveBatch(ctx(pharmacy), 'B1'), /may not receive/);
        await c.ReceiveBatch(ctx(dist), 'B1');
        await fails(c.ReceiveBatch(ctx(dist), 'B1'), /RECEIVED, not SHIPPED/);
    });

    it('dispenses units; the batch is DISPENSED when all are gone', async () => {
        await toPharmacy();
        await c.DispenseUnit(ctx(pharmacy), 'B1', 'S1');
        expect(await verify('S1')).to.equal('ALREADY_DISPENSED');
        expect(await verify('S2')).to.equal('OK');
        await c.DispenseUnit(ctx(pharmacy), 'B1', 'S2');
        expect((await read()).status).to.equal(Status.DISPENSED);
    });

    it('refuses dispensing by others, twice, of unknown units, early', async () => {
        await produce();
        await fails(c.DispenseUnit(ctx(mfr), 'B1', 'S1'), /may not dispense$/);
        await c.ShipBatch(ctx(mfr), 'B1', 'DistributorMSP');
        await c.ReceiveBatch(ctx(dist), 'B1');
        await c.ShipBatch(ctx(dist), 'B1', 'PharmacyMSP');
        await fails(
            c.DispenseUnit(ctx(pharmacy), 'B1', 'S1'),
            /may not dispense from/,
        );
        await c.ReceiveBatch(ctx(pharmacy), 'B1');
        await c.DispenseUnit(ctx(pharmacy), 'B1', 'S1');
        await fails(
            c.DispenseUnit(ctx(pharmacy), 'B1', 'S1'),
            /not an undispensed unit/,
        );
        await fails(
            c.DispenseUnit(ctx(pharmacy), 'B1', 'S7'),
            /not an undispensed unit/,
        );
        await c.RecallBatch(ctx(regulator), 'B1', 'contamination');
        await fails(
            c.DispenseUnit(ctx(pharmacy), 'B1', 'S2'),
            /only RECEIVED stock/,
        );
    });

    it('recalls once, for the regulator or maker, with a reason', async () => {
        await toPharmacy();
        await fails(c.RecallBatch(ctx(pharmacy), 'B1', 'x'), /may not recall/);
        await fails(c.RecallBatch(ctx(regulator), 'B1', ' '), /reason must be/);
        await c.RecallBatch(ctx(regulator), 'B1', 'Nitrosamine above limit');
        const b = await read();
        expect(b).to.include({status: Status.RECALLED, holder: 'PharmacyMSP'});
        expect(stub.events.at(-1)?.name).to.equal('BatchRecalled');
        expect(await verify('S1')).to.equal('RECALLED');
        await fails(c.RecallBatch(ctx(mfr), 'B1', 'again'), /already recalled/);
    });

    it('verifies unknown and malformed serials', async () => {
        expect(await verify('ZZ999')).to.equal('UNKNOWN');
        await fails(c.VerifySerial(ctx(pharmacy), 'S-1'), /invalid serial/);
    });

    it('stores price terms privately, from transient data only', async () => {
        await produce();
        await fails(c.SetTerms(ctx(dist), 'B1'), /may not set terms/);
        await fails(c.SetTerms(ctx(mfr), 'B1'), /transient data "terms"/);
        const send = (t: unknown) => {
            stub.transient.set('terms', Buffer.from(JSON.stringify(t)));
            return c.SetTerms(ctx(mfr), 'B1');
        };
        await fails(send({unitPrice: 0, currency: 'EUR'}), /unitPrice must be/);
        await fails(send({unitPrice: '3', currency: 'EUR'}), /unitPrice must be/);
        await fails(send({unitPrice: 3, currency: 'eur'}), /currency must be/);
        await fails(send({unitPrice: 3}), /currency must be/);
        await send({unitPrice: 0.42, currency: 'EUR', note: 'dropped'});
        expect(JSON.parse(await c.ReadTerms(ctx(dist), 'B1'))).to.deep.equal({
            batch: 'B1',
            currency: 'EUR',
            unitPrice: 0.42,
        });
        expect(stub.state.get('B1')?.toString()).to.not.contain('0.42');
        await fails(c.ReadTerms(ctx(dist), 'B9'), /no terms for batch B9/);
    });

    it('returns the history oldest first and refuses unknown batches', async () => {
        await toPharmacy();
        const h = JSON.parse(await c.GetHistory(ctx(regulator), 'B1')) as {
            status: string;
            holder: string;
        }[];
        expect(h.map((x) => x.status)).to.deep.equal([
            'PRODUCED',
            'SHIPPED',
            'RECEIVED',
            'SHIPPED',
            'RECEIVED',
        ]);
        expect(h[4].holder).to.equal('PharmacyMSP');
        await fails(c.ReadBatch(ctx(mfr), 'B9'), /does not exist/);
        await fails(c.GetHistory(ctx(mfr), '?'), /invalid batch id/);
    });
});
