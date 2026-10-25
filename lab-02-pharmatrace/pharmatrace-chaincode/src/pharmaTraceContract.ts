/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Lab 2: PharmaTrace. A manufacturer produces a serialized batch, ships it to a
 * distributor, who ships it to a pharmacy, which dispenses units. Custody moves
 * only with the endorsement of both holder and receiver (state-based endorsement).
 * The regulator or the manufacturer may recall a batch; anyone may verify a serial.
 */
import {Context, Contract, Info, Returns, Transaction} from 'fabric-contract-api';
import {KeyEndorsementPolicy} from 'fabric-shim';
import {
    Batch,
    ID,
    NEXT_HOLDER,
    RECALLERS,
    SERIAL,
    SERIAL_INDEX,
    Status,
    TERMS,
    validGtin,
} from './batch';

@Info({title: 'PharmaTraceContract', description: 'Serialized medicine batches'})
export class PharmaTraceContract extends Contract {
    /** The manufacturer registers a batch and its serial numbers. */
    @Transaction()
    public async ProduceBatch(
        ctx: Context,
        id: string,
        gtin: string,
        product: string,
        serialsJson: string,
    ): Promise<void> {
        const caller = this.requireOrg(ctx, ['ManufacturerMSP'], 'produce batches');
        this.checkId(id);
        if (!validGtin(gtin)) {
            throw new Error(`invalid GTIN "${gtin}"`);
        }
        if (product.trim() === '' || product.length > 128) {
            throw new Error('product must be 1 to 128 characters');
        }
        const serials = this.parseSerials(serialsJson);
        if ((await ctx.stub.getState(id)).length > 0) {
            throw new Error(`batch ${id} already exists`);
        }
        for (const serial of serials) {
            const key = ctx.stub.createCompositeKey(SERIAL_INDEX, [serial]);
            if ((await ctx.stub.getState(key)).length > 0) {
                throw new Error(`serial ${serial} is already registered`);
            }
            await ctx.stub.putState(key, Buffer.from(id));
        }
        const b: Batch = {
            docType: 'batch',
            id,
            gtin,
            product,
            serials,
            dispensed: [],
            status: Status.PRODUCED,
            holder: caller,
            shippedTo: '',
            recallReason: '',
            updatedBy: caller,
            updatedAt: '',
        };
        await this.save(ctx, b, 'BatchUpdated');
        await this.endorsers(ctx, id, [caller]); // from now on, the holder decides
    }

    /** The holder hands the batch to the next organization in the chain. */
    @Transaction()
    public async ShipBatch(ctx: Context, id: string, to: string): Promise<void> {
        const b = await this.load(ctx, id);
        const caller = this.requireOrg(ctx, [b.holder], 'ship this batch');
        if (b.status !== Status.PRODUCED && b.status !== Status.RECEIVED) {
            throw new Error(`batch ${id} is ${b.status} and cannot be shipped`);
        }
        if (NEXT_HOLDER[caller] !== to) {
            throw new Error(`${caller} may not ship to ${to}`);
        }
        b.status = Status.SHIPPED;
        b.shippedTo = to;
        await this.save(ctx, b, 'BatchUpdated');
        await this.endorsers(ctx, id, [caller, to]); // receipt needs both of them
    }

    /** The receiver takes custody; holder's and receiver's peers both endorse. */
    @Transaction()
    public async ReceiveBatch(ctx: Context, id: string): Promise<void> {
        const b = await this.load(ctx, id);
        if (b.status !== Status.SHIPPED) {
            throw new Error(`batch ${id} is ${b.status}, not SHIPPED`);
        }
        const caller = this.requireOrg(ctx, [b.shippedTo], 'receive this batch');
        b.holder = caller;
        b.shippedTo = '';
        b.status = Status.RECEIVED;
        await this.save(ctx, b, 'BatchUpdated');
        await this.endorsers(ctx, id, [caller]);
    }

    /** The pharmacy dispenses a unit: the ledger gets a serial, never a patient. */
    @Transaction()
    public async DispenseUnit(
        ctx: Context,
        id: string,
        serial: string,
    ): Promise<void> {
        const b = await this.load(ctx, id);
        this.requireOrg(ctx, ['PharmacyMSP'], 'dispense');
        this.requireOrg(ctx, [b.holder], 'dispense from this batch');
        if (b.status !== Status.RECEIVED) {
            throw new Error(
                `batch ${id} is ${b.status}; only RECEIVED stock is dispensed`,
            );
        }
        if (!b.serials.includes(serial) || b.dispensed.includes(serial)) {
            throw new Error(`serial ${serial} is not an undispensed unit of ${id}`);
        }
        b.dispensed.push(serial);
        if (b.dispensed.length === b.serials.length) {
            b.status = Status.DISPENSED;
        }
        await this.save(ctx, b, 'BatchUpdated');
    }

    /** The regulator or the manufacturer recalls a batch, wherever it is. */
    @Transaction()
    public async RecallBatch(
        ctx: Context,
        id: string,
        reason: string,
    ): Promise<void> {
        const b = await this.load(ctx, id);
        this.requireOrg(ctx, RECALLERS, 'recall batches');
        if (b.status === Status.RECALLED) {
            throw new Error(`batch ${id} is already recalled`);
        }
        if (reason.trim() === '' || reason.length > 256) {
            throw new Error('reason must be 1 to 256 characters');
        }
        b.status = Status.RECALLED;
        b.recallReason = reason;
        await this.save(ctx, b, 'BatchRecalled');
    }

    /** Price terms between manufacturer and distributor, from transient data. */
    @Transaction()
    public async SetTerms(ctx: Context, id: string): Promise<void> {
        this.requireOrg(ctx, ['ManufacturerMSP'], 'set terms');
        await this.load(ctx, id);
        const raw = ctx.stub.getTransient().get('terms');
        if (!raw) {
            throw new Error('the terms must be sent as transient data "terms"');
        }
        const t = JSON.parse(Buffer.from(raw).toString('utf8')) as Record<
            string,
            unknown
        >;
        if (typeof t.unitPrice !== 'number' || !(t.unitPrice > 0)) {
            throw new Error('unitPrice must be a positive number');
        }
        if (typeof t.currency !== 'string' || !/^[A-Z]{3}$/.test(t.currency)) {
            throw new Error('currency must be a three-letter ISO code');
        }
        const terms = {batch: id, currency: t.currency, unitPrice: t.unitPrice};
        await ctx.stub.putPrivateData(
            TERMS,
            id,
            Buffer.from(JSON.stringify(terms)),
        );
    }

    @Transaction(false)
    @Returns('string')
    public async ReadTerms(ctx: Context, id: string): Promise<string> {
        this.checkId(id);
        const data = await ctx.stub.getPrivateData(TERMS, id);
        if (data.length === 0) {
            throw new Error(`no terms for batch ${id}`);
        }
        return Buffer.from(data).toString('utf8');
    }

    @Transaction(false)
    @Returns('string')
    public async ReadBatch(ctx: Context, id: string): Promise<string> {
        return JSON.stringify(await this.load(ctx, id));
    }

    /** A pharmacist's scan: is this pack genuine, and may I dispense it? */
    @Transaction(false)
    @Returns('string')
    public async VerifySerial(ctx: Context, serial: string): Promise<string> {
        if (!SERIAL.test(serial)) {
            throw new Error(`invalid serial "${serial}"`);
        }
        const key = ctx.stub.createCompositeKey(SERIAL_INDEX, [serial]);
        const batchId = Buffer.from(await ctx.stub.getState(key)).toString('utf8');
        if (batchId === '') {
            return JSON.stringify({serial, verdict: 'UNKNOWN'});
        }
        const b = await this.load(ctx, batchId);
        let verdict = 'OK';
        if (b.status === Status.RECALLED) {
            verdict = 'RECALLED';
        } else if (b.dispensed.includes(serial)) {
            verdict = 'ALREADY_DISPENSED';
        }
        return JSON.stringify({serial, verdict, batch: b.id, product: b.product});
    }

    @Transaction(false)
    @Returns('string')
    public async GetHistory(ctx: Context, id: string): Promise<string> {
        this.checkId(id);
        const it = await ctx.stub.getHistoryForKey(id);
        const out: {status: string; holder: string; by: string}[] = [];
        try {
            for (let r = await it.next(); !r.done; r = await it.next()) {
                const b = JSON.parse(
                    Buffer.from(r.value.value).toString('utf8'),
                ) as Batch;
                out.unshift({status: b.status, holder: b.holder, by: b.updatedBy});
            }
        } finally {
            await it.close();
        }
        return JSON.stringify(out);
    }

    // ---- helpers ---------------------------------------------------------------

    private requireOrg(ctx: Context, allowed: string[], action: string): string {
        const caller = ctx.clientIdentity.getMSPID();
        if (!allowed.includes(caller)) {
            throw new Error(`${caller} may not ${action}`);
        }
        return caller;
    }

    private checkId(id: string): void {
        if (!ID.test(id)) {
            throw new Error(`invalid batch id "${id}"`);
        }
    }

    private parseSerials(json: string): string[] {
        let serials: unknown;
        try {
            serials = JSON.parse(json);
        } catch {
            throw new Error('serials must be a JSON array of strings');
        }
        if (
            !Array.isArray(serials) ||
            serials.length < 1 ||
            serials.length > 100 ||
            !serials.every((s) => typeof s === 'string' && SERIAL.test(s)) ||
            new Set(serials).size !== serials.length
        ) {
            throw new Error('serials must be 1 to 100 unique serial numbers');
        }
        return serials as string[];
    }

    private async load(ctx: Context, id: string): Promise<Batch> {
        this.checkId(id);
        const data = await ctx.stub.getState(id);
        if (data.length === 0) {
            throw new Error(`batch ${id} does not exist`);
        }
        return JSON.parse(Buffer.from(data).toString('utf8')) as Batch;
    }

    /** Only these organizations' peers may endorse the next change to the batch. */
    private async endorsers(
        ctx: Context,
        id: string,
        orgs: string[],
    ): Promise<void> {
        const policy = new KeyEndorsementPolicy();
        policy.addOrgs('PEER', ...orgs);
        await ctx.stub.setStateValidationParameter(id, policy.getPolicy());
    }

    /** Sorted keys: endorsers write identical bytes. One event per transaction. */
    private async save(ctx: Context, b: Batch, event: string): Promise<void> {
        b.updatedBy = ctx.clientIdentity.getMSPID();
        b.updatedAt = ctx.stub.getDateTimestamp().toISOString();
        const json = JSON.stringify(b, Object.keys(b).sort());
        await ctx.stub.putState(b.id, Buffer.from(json));
        ctx.stub.setEvent(event, Buffer.from(json));
    }
}
