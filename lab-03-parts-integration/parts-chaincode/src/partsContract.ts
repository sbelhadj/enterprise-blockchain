/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Lab 3: a shared record of serialized aircraft parts for a parts maker, a
 * maintenance, repair and overhaul (MRO) provider and an airline.
 */
import {Context, Contract, Info, Returns, Transaction} from 'fabric-contract-api';
import {EVENTS, HASH, Part, REGISTRATION, SERIAL, Status} from './part';

@Info({title: 'PartsContract', description: 'Serialized aircraft part records'})
export class PartsContract extends Contract {
    /** The maker registers a new part with the hash of its release certificate. */
    @Transaction()
    public async RegisterPart(
        ctx: Context,
        serial: string,
        partNumber: string,
        description: string,
        certHash: string,
    ): Promise<void> {
        this.requireOrg(ctx, ['PartsMakerMSP'], 'register parts');
        this.checkSerial(serial);
        this.checkText('partNumber', partNumber, 32);
        this.checkText('description', description, 128);
        this.checkHash(certHash);
        if ((await ctx.stub.getState(serial)).length > 0) {
            throw new Error(`part ${serial} already exists`);
        }
        const p: Part = {
            docType: 'part',
            serial,
            partNumber,
            description,
            status: Status.SERVICEABLE,
            aircraft: '',
            position: '',
            cycles: 0,
            lastDocHash: certHash,
            updatedBy: '',
            updatedAt: '',
        };
        await this.save(ctx, p, 'REGISTER');
    }

    /**
     * INSTALL needs aircraft and position; REPAIR needs the hash of the new release
     * certificate. Other events ignore the arguments they do not use.
     */
    @Transaction()
    public async RecordEvent(
        ctx: Context,
        serial: string,
        type: string,
        aircraft: string,
        position: string,
        docHash: string,
    ): Promise<void> {
        const rule = Object.prototype.hasOwnProperty.call(EVENTS, type)
            ? EVENTS[type]
            : undefined;
        if (!rule) {
            throw new Error(`unknown event type "${type}"`);
        }
        this.requireOrg(ctx, rule.by, `record ${type}`);
        const p = await this.load(ctx, serial);
        if (!rule.from.includes(p.status)) {
            throw new Error(
                `part ${serial} is ${p.status}; ${type} is not allowed`,
            );
        }
        if (type === 'INSTALL') {
            if (!REGISTRATION.test(aircraft)) {
                throw new Error(`invalid aircraft registration "${aircraft}"`);
            }
            this.checkText('position', position, 32);
            p.aircraft = aircraft;
            p.position = position;
        } else if (type === 'REMOVE') {
            p.aircraft = '';
            p.position = '';
        } else if (type === 'REPAIR') {
            this.checkHash(docHash);
            p.lastDocHash = docHash;
        }
        p.status = rule.to;
        await this.save(ctx, p, type);
    }

    /** The operator adds flight cycles. Concurrent reports on one part conflict. */
    @Transaction()
    public async RecordCycles(
        ctx: Context,
        serial: string,
        cycles: string,
    ): Promise<void> {
        this.requireOrg(ctx, ['AirlineMSP'], 'record cycles');
        const n = Number(cycles);
        if (!Number.isInteger(n) || n < 1 || n > 100) {
            throw new Error('cycles must be a whole number from 1 to 100');
        }
        const p = await this.load(ctx, serial);
        if (p.status !== Status.INSTALLED) {
            throw new Error(
                `part ${serial} is ${p.status}; only installed parts fly`,
            );
        }
        p.cycles += n;
        await this.save(ctx, p, 'CYCLES');
    }

    @Transaction(false)
    @Returns('string')
    public async ReadPart(ctx: Context, serial: string): Promise<string> {
        return JSON.stringify(await this.load(ctx, serial));
    }

    /** Every part, for reconciliation. A real network would page through them. */
    @Transaction(false)
    @Returns('string')
    public async ListParts(ctx: Context): Promise<string> {
        const it = await ctx.stub.getStateByRange('', '');
        const parts: Part[] = [];
        try {
            for (let r = await it.next(); !r.done; r = await it.next()) {
                parts.push(
                    JSON.parse(Buffer.from(r.value.value).toString()) as Part,
                );
            }
        } finally {
            await it.close();
        }
        return JSON.stringify(parts);
    }

    @Transaction(false)
    @Returns('string')
    public async GetHistory(ctx: Context, serial: string): Promise<string> {
        this.checkSerial(serial);
        const it = await ctx.stub.getHistoryForKey(serial);
        const out: Record<string, unknown>[] = [];
        try {
            for (let r = await it.next(); !r.done; r = await it.next()) {
                const p = JSON.parse(Buffer.from(r.value.value).toString()) as Part;
                const {status, aircraft, position, cycles, updatedBy, updatedAt} =
                    p;
                out.unshift({
                    txId: r.value.txId,
                    status,
                    aircraft,
                    position,
                    cycles,
                    by: updatedBy,
                    at: updatedAt,
                });
            }
        } finally {
            await it.close();
        }
        return JSON.stringify(out);
    }

    // ---- helpers ---------------------------------------------------------------

    private requireOrg(ctx: Context, allowed: string[], action: string): void {
        const caller = ctx.clientIdentity.getMSPID();
        if (!allowed.includes(caller)) {
            throw new Error(`${caller} may not ${action}`);
        }
    }

    private checkSerial(serial: string): void {
        if (!SERIAL.test(serial)) {
            throw new Error(`invalid serial "${serial}"`);
        }
    }

    private checkText(field: string, value: string, max: number): void {
        if (value.trim() === '' || value.length > max) {
            throw new Error(`${field} must be 1 to ${max} characters`);
        }
    }

    private checkHash(hash: string): void {
        if (!HASH.test(hash)) {
            throw new Error('document hash must be 64 lowercase hex characters');
        }
    }

    private async load(ctx: Context, serial: string): Promise<Part> {
        this.checkSerial(serial);
        const data = await ctx.stub.getState(serial);
        if (data.length === 0) {
            throw new Error(`part ${serial} does not exist`);
        }
        return JSON.parse(Buffer.from(data).toString('utf8')) as Part;
    }

    /** Sorted keys: endorsers write identical bytes. One event per transaction. */
    private async save(ctx: Context, p: Part, type: string): Promise<void> {
        p.updatedBy = ctx.clientIdentity.getMSPID();
        p.updatedAt = ctx.stub.getDateTimestamp().toISOString();
        const json = JSON.stringify(p, Object.keys(p).sort());
        await ctx.stub.putState(p.serial, Buffer.from(json));
        const event = {type, part: JSON.parse(json) as Part};
        ctx.stub.setEvent('PartEvent', Buffer.from(JSON.stringify(event)));
    }
}
