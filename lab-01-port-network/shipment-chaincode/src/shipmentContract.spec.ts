/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {expect} from 'chai';
import {contracts, ShipmentContract} from './index';
import {Shipment, Status} from './shipment';
import {context, FakeIdentity, FakeStub} from './test-support/fakes';

const line = new FakeIdentity('ShippingLineMSP');
const terminal = new FakeIdentity('PortTerminalMSP');
const customs = new FakeIdentity('CustomsMSP');
const forwarder = new FakeIdentity('FreightForwarderMSP');

describe('ShipmentContract', () => {
    let c: ShipmentContract;
    let stub: FakeStub;
    const create = (id = 'SH1', containerNo = 'MSCU1234565', who = line) =>
        c.CreateShipment(
            context(stub, who),
            id,
            containerNo,
            'MSC Aurora',
            'CNSHA',
            'Carthage Foods',
        );
    const record = (event: string, who: FakeIdentity, id = 'SH1') =>
        c.RecordEvent(context(stub, who), id, event);
    const read = async (id = 'SH1') =>
        JSON.parse(await c.ReadShipment(context(stub, customs), id)) as Shipment;
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
        c = new ShipmentContract();
        stub = new FakeStub();
    });

    it('is the exported contract', () => {
        expect(contracts).to.deep.equal([ShipmentContract]);
    });

    it('creates a manifested shipment and emits an event', async () => {
        await create();
        const s = await read();
        expect(s).to.include({
            status: Status.MANIFESTED,
            updatedBy: 'ShippingLineMSP',
        });
        expect(s.updatedAt).to.equal('2026-10-24T10:00:00.000Z');
        expect(stub.events[0].name).to.equal('ShipmentEvent');
        expect(
            Object.keys(JSON.parse(stub.events[0].payload) as object),
        ).to.deep.equal(Object.keys(s).sort());
    });

    it('lets only the shipping line create shipments', async () => {
        await fails(
            create('SH1', 'MSCU1234565', terminal),
            /PortTerminalMSP may not create/,
        );
    });

    it('validates the id, container number and text fields', async () => {
        await fails(create('bad id'), /invalid shipment id/);
        await fails(create('SH1', 'MSC1234565'), /invalid container number/);
        await fails(
            c.CreateShipment(
                context(stub, line),
                'SH1',
                'MSCU1234565',
                ' ',
                'CNSHA',
                'X',
            ),
            /vessel must be/,
        );
        await fails(
            c.CreateShipment(
                context(stub, line),
                'SH1',
                'MSCU1234565',
                'V',
                'CNSHA',
                'x'.repeat(129),
            ),
            /consignee must be/,
        );
    });

    it('refuses a duplicate shipment', async () => {
        await create();
        await fails(create(), /already exists/);
    });

    it('runs the full path with a customs hold and a booked pickup', async () => {
        await create();
        await record('ARRIVE', line);
        await record('DISCHARGE', terminal);
        await record('HOLD', customs);
        await record('RELEASE', customs);
        stub.txId = 'tx6';
        await record('BOOK_PICKUP', forwarder);
        await record('GATE_OUT', terminal);
        expect((await read()).status).to.equal(Status.GATED_OUT);
        const history = JSON.parse(
            await c.GetHistory(context(stub, line), 'SH1'),
        ) as {
            status: string;
            by: string;
        }[];
        expect(history.map((h) => h.status)).to.deep.equal([
            'MANIFESTED',
            'ARRIVED',
            'DISCHARGED',
            'HELD',
            'RELEASED',
            'PICKUP_BOOKED',
            'GATED_OUT',
        ]);
        expect(history[5].by).to.equal('FreightForwarderMSP');
    });

    it('allows release after discharge and gate-out after release', async () => {
        await create();
        await record('ARRIVE', line);
        await record('DISCHARGE', terminal);
        await record('RELEASE', customs);
        await record('GATE_OUT', terminal);
        expect((await read()).status).to.equal(Status.GATED_OUT);
    });

    it('refuses events out of order, by the wrong org or unknown', async () => {
        await create();
        await fails(
            record('DISCHARGE', terminal),
            /is MANIFESTED; DISCHARGE needs ARRIVED/,
        );
        await fails(record('ARRIVE', customs), /CustomsMSP may not record ARRIVE/);
        await fails(record('SINK', line), /unknown event "SINK"/);
        await fails(record('toString', line), /unknown event/);
        await fails(record('ARRIVE', line, 'SH9'), /does not exist/);
    });

    it('reports whether a shipment exists', async () => {
        expect(await c.ShipmentExists(context(stub, line), 'SH1')).to.equal(false);
        await create();
        expect(await c.ShipmentExists(context(stub, line), 'SH1')).to.equal(true);
    });
});
