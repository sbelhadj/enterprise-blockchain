/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Lab 1: shipment status for a port community. ShippingLine manifests a container,
 * then each organization records the events it is responsible for (see EVENTS).
 */
import {Context, Contract, Info, Returns, Transaction} from 'fabric-contract-api';
import {CONTAINER_NO, EVENTS, ID, Shipment, Status} from './shipment';

@Info({title: 'ShipmentContract', description: 'Import shipment status at a port'})
export class ShipmentContract extends Contract {
    /** The carrier declares a container on its manifest. */
    @Transaction()
    public async CreateShipment(
        ctx: Context,
        id: string,
        containerNo: string,
        vessel: string,
        portOfLoading: string,
        consignee: string,
    ): Promise<void> {
        const caller = ctx.clientIdentity.getMSPID();
        if (caller !== 'ShippingLineMSP') {
            throw new Error(
                `${caller} may not create shipments; only ShippingLineMSP may`,
            );
        }
        this.checkId(id);
        if (!CONTAINER_NO.test(containerNo)) {
            throw new Error(`invalid container number "${containerNo}"`);
        }
        for (const [field, value] of Object.entries({
            vessel,
            portOfLoading,
            consignee,
        })) {
            if (value.trim() === '' || value.length > 128) {
                throw new Error(`${field} must be 1 to 128 characters`);
            }
        }
        if (await this.ShipmentExists(ctx, id)) {
            throw new Error(`shipment ${id} already exists`);
        }
        const s: Shipment = {
            docType: 'shipment',
            id,
            containerNo,
            vessel,
            portOfLoading,
            consignee,
            status: Status.MANIFESTED,
            updatedBy: caller,
            updatedAt: ctx.stub.getDateTimestamp().toISOString(),
        };
        await this.save(ctx, s);
    }

    /** An organization records an event it is responsible for, in order. */
    @Transaction()
    public async RecordEvent(
        ctx: Context,
        id: string,
        event: string,
    ): Promise<void> {
        const rule = Object.prototype.hasOwnProperty.call(EVENTS, event)
            ? EVENTS[event]
            : undefined;
        if (!rule) {
            throw new Error(`unknown event "${event}"`);
        }
        const caller = ctx.clientIdentity.getMSPID();
        if (caller !== rule.by) {
            throw new Error(
                `${caller} may not record ${event}; only ${rule.by} may`,
            );
        }
        const s = JSON.parse(await this.ReadShipment(ctx, id)) as Shipment;
        if (!rule.from.includes(s.status)) {
            throw new Error(
                `shipment ${id} is ${s.status}; ` +
                    `${event} needs ${rule.from.join(' or ')}`,
            );
        }
        s.status = rule.to;
        s.updatedBy = caller;
        s.updatedAt = ctx.stub.getDateTimestamp().toISOString();
        await this.save(ctx, s);
    }

    @Transaction(false)
    @Returns('string')
    public async ReadShipment(ctx: Context, id: string): Promise<string> {
        this.checkId(id);
        const data = await ctx.stub.getState(id);
        if (data.length === 0) {
            throw new Error(`shipment ${id} does not exist`);
        }
        return Buffer.from(data).toString('utf8');
    }

    @Transaction(false)
    @Returns('boolean')
    public async ShipmentExists(ctx: Context, id: string): Promise<boolean> {
        return (await ctx.stub.getState(id)).length > 0;
    }

    /** Every committed version of the shipment, oldest first. */
    @Transaction(false)
    @Returns('string')
    public async GetHistory(ctx: Context, id: string): Promise<string> {
        this.checkId(id);
        const it = await ctx.stub.getHistoryForKey(id);
        const out: {txId: string; status: string; by: string}[] = [];
        try {
            for (let r = await it.next(); !r.done; r = await it.next()) {
                const s = JSON.parse(
                    Buffer.from(r.value.value).toString('utf8'),
                ) as Shipment;
                out.unshift({
                    txId: r.value.txId,
                    status: s.status,
                    by: s.updatedBy,
                });
            }
        } finally {
            await it.close();
        }
        return JSON.stringify(out);
    }

    private checkId(id: string): void {
        if (!ID.test(id)) {
            throw new Error(`invalid shipment id "${id}"`);
        }
    }

    /** Fixed field order, so every endorser writes the same bytes. */
    private async save(ctx: Context, s: Shipment): Promise<void> {
        const json = JSON.stringify(s, Object.keys(s).sort());
        await ctx.stub.putState(s.id, Buffer.from(json));
        ctx.stub.setEvent('ShipmentEvent', Buffer.from(json));
    }
}
