/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing 7.4: the private terms of a letter of credit. The terms live in the
 * collection lcBankTerms, shared by the two banks; every other channel member sees
 * only their hash. Inputs that must not reach the ledger arrive as transient data,
 * never as arguments.
 */
import {createHash} from 'node:crypto';
import {Context, Contract, Info, Returns, Transaction} from 'fabric-contract-api';

const TERMS = 'lcBankTerms';

/** Sorted keys: the same terms always give the same bytes, and the same hash. */
function canonical(value: unknown): string {
    if (Array.isArray(value)) {
        return '[' + value.map(canonical).join(',') + ']';
    }
    if (value !== null && typeof value === 'object') {
        const o = value as Record<string, unknown>;
        return (
            '{' +
            Object.keys(o)
                .sort()
                .map((k) => JSON.stringify(k) + ':' + canonical(o[k]))
                .join(',') +
            '}'
        );
    }
    return JSON.stringify(value);
}

function parseTerms(raw: string): Buffer {
    let terms: unknown;
    try {
        terms = JSON.parse(raw);
    } catch {
        throw new Error('the terms are not valid JSON');
    }
    if (terms === null || typeof terms !== 'object' || Array.isArray(terms)) {
        throw new Error('the terms must be a JSON object');
    }
    return Buffer.from(canonical(terms));
}

function transient(ctx: Context, name: string): string {
    const value = ctx.stub.getTransient().get(name);
    if (!value || value.length === 0) {
        throw new Error(`transient field "${name}" is required`);
    }
    return Buffer.from(value).toString('utf8');
}

@Info({title: 'LCTermsContract', description: 'Private terms of letters of credit'})
export class LCTermsContract extends Contract {
    constructor() {
        super('LCTermsContract');
    }

    /** Stores the terms passed in the transient field "terms". */
    @Transaction()
    public async PutTerms(ctx: Context, id: string): Promise<void> {
        const terms = parseTerms(transient(ctx, 'terms'));
        await ctx.stub.putPrivateData(TERMS, id, terms);
        ctx.stub.setEvent('TermsSet', Buffer.from(JSON.stringify({id})));
    }

    /** Returns the terms; only peers of the collection's members hold them. */
    @Transaction(false)
    @Returns('string')
    public async ReadTerms(ctx: Context, id: string): Promise<string> {
        const data = await ctx.stub.getPrivateData(TERMS, id);
        if (data.length === 0) {
            throw new Error(`no terms for ${id}`);
        }
        return Buffer.from(data).toString('utf8');
    }

    /** The SHA-256 hash of the terms, which every peer on the channel holds. */
    @Transaction(false)
    @Returns('string')
    public async TermsHash(ctx: Context, id: string): Promise<string> {
        const hash = await ctx.stub.getPrivateDataHash(TERMS, id);
        if (hash.length === 0) {
            throw new Error(`no terms hash for ${id}`);
        }
        return Buffer.from(hash).toString('hex');
    }

    /** Lets anyone holding a copy of the terms check it against the hash. */
    @Transaction(false)
    @Returns('string')
    public async VerifyTerms(ctx: Context, id: string): Promise<string> {
        const candidate = parseTerms(transient(ctx, 'terms'));
        const onChannel = Buffer.from(await this.TermsHash(ctx, id), 'hex');
        const computed = createHash('sha256').update(candidate).digest();
        return computed.equals(onChannel) ? 'match' : 'no match';
    }

    /** Removes the terms and their private history from every member peer. */
    @Transaction()
    public async PurgeTerms(ctx: Context, id: string): Promise<void> {
        await ctx.stub.purgePrivateData(TERMS, id);
    }

    /** A note only the caller's organization holds, in its implicit collection. */
    @Transaction()
    public async PutCreditNote(ctx: Context, id: string): Promise<void> {
        const note = transient(ctx, 'note');
        await ctx.stub.putPrivateData(this.own(ctx), id, Buffer.from(note));
    }

    @Transaction(false)
    @Returns('string')
    public async ReadCreditNote(ctx: Context, id: string): Promise<string> {
        const data = await ctx.stub.getPrivateData(this.own(ctx), id);
        if (data.length === 0) {
            throw new Error(`no credit note for ${id} in ${this.own(ctx)}`);
        }
        return Buffer.from(data).toString('utf8');
    }

    private own(ctx: Context): string {
        return `_implicit_org_${ctx.clientIdentity.getMSPID()}`;
    }
}
