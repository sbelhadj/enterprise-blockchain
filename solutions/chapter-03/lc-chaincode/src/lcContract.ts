/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {Context, Contract, Info, Returns, Transaction} from 'fabric-contract-api';
import {KeyEndorsementPolicy} from 'fabric-shim';
import stringify from 'json-stringify-deterministic';
import sortKeysRecursive from 'sort-keys-recursive';
import {LCStatus, LetterOfCredit} from './letterOfCredit';
import {
    checkCurrency,
    checkExpiry,
    checkHash,
    checkId,
    checkText,
    parseAmount,
} from './validation';

/** Composite-key index: one empty entry per LC, keyed by issuing bank then LC id. */
export const ISSUER_INDEX = 'issuer~lc';
/** Exercise 3.2: the same kind of index, keyed by beneficiary (version 1.2). */
export const BENEFICIARY_INDEX = 'beneficiary~lc';
/** Certificate attribute that Fabric CA writes into an LC officer's certificate. */
export const ROLE_ATTRIBUTE = 'lc.role';

@Info({
    title: 'LetterOfCreditContract',
    description: 'Documentary letters of credit between two banks',
})
export class LetterOfCreditContract extends Contract {
    /**
     * The issuing bank opens a letter of credit in favor of an exporter.
     * Caller: a client of the issuing bank whose certificate carries lc.role=issuer.
     */
    @Transaction()
    public async IssueLC(
        ctx: Context,
        id: string,
        applicant: string,
        beneficiary: string,
        advisingBank: string,
        amount: string,
        currency: string,
        expiryDate: string,
        goods: string,
    ): Promise<void> {
        if (!ctx.clientIdentity.assertAttributeValue(ROLE_ATTRIBUTE, 'issuer')) {
            throw new Error(
                'only an LC officer (lc.role=issuer) may issue a letter of credit',
            );
        }
        const issuingBank = ctx.clientIdentity.getMSPID();
        checkId(id);
        checkText('applicant', applicant, 128);
        checkText('beneficiary', beneficiary, 128);
        checkText('goods', goods, 256);
        checkCurrency(currency);
        if (advisingBank === issuingBank || advisingBank.trim() === '') {
            throw new Error('the advising bank must be another organization');
        }
        const now = this.txTime(ctx);
        checkExpiry(expiryDate, now.slice(0, 10));
        if (await this.LCExists(ctx, id)) {
            throw new Error(`letter of credit ${id} already exists`);
        }

        const lc: LetterOfCredit = {
            docType: 'lc',
            id,
            applicant,
            beneficiary,
            issuingBank,
            advisingBank,
            amount: parseAmount(amount),
            currency,
            expiryDate,
            goods,
            documentsHash: '',
            status: LCStatus.ISSUED,
            rejectionReason: '',
            issuedAt: now,
            updatedAt: now,
        };
        await this.save(ctx, lc);

        // Index entry for GetLCsByIssuingBank. An empty value would delete it.
        const indexKey = ctx.stub.createCompositeKey(ISSUER_INDEX, [issuingBank, id]);
        await ctx.stub.putState(indexKey, Buffer.from('\u0000'));
        const byBeneficiary = ctx.stub.createCompositeKey(BENEFICIARY_INDEX, [
            beneficiary,
            id,
        ]);
        await ctx.stub.putState(byBeneficiary, Buffer.from('\u0000'));

        // From now on, any change to this LC must be endorsed by peers of both banks on it.
        const policy = new KeyEndorsementPolicy();
        policy.addOrgs('PEER', issuingBank, advisingBank);
        await ctx.stub.setStateValidationParameter(id, policy.getPolicy());

        this.emit(ctx, 'LCIssued', lc);
    }

    /** The advising bank accepts the LC on behalf of its customer, the exporter. */
    @Transaction()
    public async AcceptLC(ctx: Context, id: string): Promise<void> {
        const lc = await this.readForUpdate(ctx, id);
        this.requireBank(ctx, lc.advisingBank, 'accept');
        this.move(ctx, lc, LCStatus.ISSUED, LCStatus.ACCEPTED);
        await this.save(ctx, lc);
        this.emit(ctx, 'LCAccepted', lc);
    }

    /** Exercise 3.1: the advising bank refuses an LC it has not accepted yet. */
    @Transaction()
    public async RejectLC(ctx: Context, id: string, reason: string): Promise<void> {
        checkText('reason', reason, 256);
        const lc = await this.readForUpdate(ctx, id);
        this.requireBank(ctx, lc.advisingBank, 'reject');
        this.move(ctx, lc, LCStatus.ISSUED, LCStatus.REJECTED);
        lc.rejectionReason = reason;
        await this.save(ctx, lc);
        this.emit(ctx, 'LCRejected', lc);
    }

    /**
     * Exercise 3.1: the issuing bank changes the amount, the expiry date or both of an
     * LC that is still ISSUED. An empty argument leaves that field as it is. The LC's
     * key-level policy still needs the advising bank's peer, so the beneficiary's bank
     * endorses every amendment, as UCP 600 article 10 expects it to agree to one.
     */
    @Transaction()
    public async AmendLC(
        ctx: Context,
        id: string,
        amount: string,
        expiryDate: string,
    ): Promise<void> {
        if (amount === '' && expiryDate === '') {
            throw new Error('nothing to amend: give a new amount, expiry date or both');
        }
        const lc = await this.readForUpdate(ctx, id);
        this.requireBank(ctx, lc.issuingBank, 'amend');
        if (lc.status !== LCStatus.ISSUED) {
            throw new Error(
                `letter of credit ${id} is ${lc.status}; only an ISSUED LC can be amended`,
            );
        }
        const now = this.txTime(ctx);
        if (amount !== '') {
            lc.amount = parseAmount(amount);
        }
        if (expiryDate !== '') {
            checkExpiry(expiryDate, now.slice(0, 10));
            lc.expiryDate = expiryDate;
        }
        lc.updatedAt = now;
        await this.save(ctx, lc);
        this.emit(ctx, 'LCAmended', lc);
    }

    /** The advising bank presents the documents; only their hash goes on the ledger. */
    @Transaction()
    public async PresentDocuments(
        ctx: Context,
        id: string,
        documentsHash: string,
    ): Promise<void> {
        checkHash(documentsHash);
        const lc = await this.readForUpdate(ctx, id);
        this.requireBank(ctx, lc.advisingBank, 'present documents for');
        this.move(ctx, lc, LCStatus.ACCEPTED, LCStatus.DOCUMENTS_PRESENTED);
        lc.documentsHash = documentsHash;
        await this.save(ctx, lc);
        this.emit(ctx, 'DocumentsPresented', lc);
    }

    /** The issuing bank pays against complying documents. */
    @Transaction()
    public async PayLC(ctx: Context, id: string): Promise<void> {
        const lc = await this.readForUpdate(ctx, id);
        this.requireBank(ctx, lc.issuingBank, 'pay');
        this.move(ctx, lc, LCStatus.DOCUMENTS_PRESENTED, LCStatus.PAID);
        await this.save(ctx, lc);
        this.emit(ctx, 'LCPaid', lc);
    }

    @Transaction(false)
    @Returns('LetterOfCredit')
    public async ReadLC(ctx: Context, id: string): Promise<string> {
        const data = await ctx.stub.getState(id);
        if (data.length === 0) {
            throw new Error(`letter of credit ${id} does not exist`);
        }
        return Buffer.from(data).toString('utf8');
    }

    @Transaction(false)
    @Returns('boolean')
    public async LCExists(ctx: Context, id: string): Promise<boolean> {
        const data = await ctx.stub.getState(id);
        return data.length > 0;
    }

    /**
     * One page of the LCs issued by a bank, through the composite-key index.
     * Pagination works only in queries (evaluate), never in submitted transactions.
     * The peer's bookmark is the next composite key, which contains null bytes, so the
     * contract hands it to clients base64url-encoded and decodes it on the way back in.
     */
    @Transaction(false)
    @Returns('string')
    public async GetLCsByIssuingBank(
        ctx: Context,
        issuingBank: string,
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        return this.pageIndex(ctx, ISSUER_INDEX, issuingBank, pageSize, bookmark);
    }

    /** Exercise 3.2: one page of a beneficiary's LCs, issued from version 1.2 on. */
    @Transaction(false)
    @Returns('string')
    public async GetLCsByBeneficiary(
        ctx: Context,
        beneficiary: string,
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        return this.pageIndex(ctx, BENEFICIARY_INDEX, beneficiary, pageSize, bookmark);
    }

    /** Rich query on CouchDB: one page of LCs in a given status, through indexStatus. */
    @Transaction(false)
    @Returns('string')
    public async QueryLCsByStatus(
        ctx: Context,
        status: string,
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        if (!Object.values<string>(LCStatus).includes(status)) {
            throw new Error(`unknown status ${status}`);
        }
        return this.richPage(
            ctx,
            {docType: 'lc', status},
            ['_design/indexStatusDoc', 'indexStatus'],
            pageSize,
            bookmark,
        );
    }

    /** Exercise 3.3: LCs above an amount in minor units, through indexAmount. */
    @Transaction(false)
    @Returns('string')
    public async GetLCsAboveAmount(
        ctx: Context,
        minAmount: string,
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        return this.richPage(
            ctx,
            {docType: 'lc', amount: {$gt: parseAmount(minAmount)}},
            ['_design/indexAmountDoc', 'indexAmount'],
            pageSize,
            bookmark,
        );
    }

    // v1.1 begin
    /** Every committed version of an LC from the history database, newest first. */
    @Transaction(false)
    @Returns('string')
    public async GetLCHistory(ctx: Context, id: string): Promise<string> {
        checkId(id);
        const iterator = await ctx.stub.getHistoryForKey(id);
        const history: unknown[] = [];
        try {
            for (let res = await iterator.next(); !res.done; res = await iterator.next()) {
                const m = res.value;
                history.push({
                    txId: m.txId,
                    status: m.isDelete
                        ? 'DELETED'
                        : (
                              JSON.parse(
                                  Buffer.from(m.value).toString('utf8'),
                              ) as LetterOfCredit
                          ).status,
                    timestamp: new Date(
                        Number(m.timestamp.seconds) * 1000 +
                            Math.floor(m.timestamp.nanos / 1e6),
                    ).toISOString(),
                });
            }
        } finally {
            await iterator.close();
        }
        return JSON.stringify(history);
    }
    // v1.1 end

    // ---- helpers -----------------------------------------------------------------------

    /** One page of a composite-key index whose last attribute is the LC id. */
    private async pageIndex(
        ctx: Context,
        index: string,
        value: string,
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        const size = this.pageSize(pageSize);
        const {iterator, metadata} =
            await ctx.stub.getStateByPartialCompositeKeyWithPagination(
                index,
                [value],
                size,
                this.decodeBookmark(bookmark),
            );
        const records: unknown[] = [];
        try {
            for (let res = await iterator.next(); !res.done; res = await iterator.next()) {
                const {attributes} = ctx.stub.splitCompositeKey(res.value.key);
                records.push(JSON.parse(await this.ReadLC(ctx, attributes[1])));
            }
        } finally {
            await iterator.close();
        }
        return this.page(records, metadata);
    }

    /** One page of a CouchDB rich query that names the index it expects. */
    private async richPage(
        ctx: Context,
        selector: Record<string, unknown>,
        index: string[],
        pageSize: string,
        bookmark: string,
    ): Promise<string> {
        const query = JSON.stringify({selector, use_index: index});
        const {iterator, metadata} = await ctx.stub.getQueryResultWithPagination(
            query,
            this.pageSize(pageSize),
            this.decodeBookmark(bookmark),
        );
        const records: unknown[] = [];
        try {
            for (let res = await iterator.next(); !res.done; res = await iterator.next()) {
                records.push(JSON.parse(Buffer.from(res.value.value).toString('utf8')));
            }
        } finally {
            await iterator.close();
        }
        return this.page(records, metadata);
    }

    /** Time comes from the transaction header, so every endorser gets the same value. */
    private txTime(ctx: Context): string {
        return ctx.stub.getDateTimestamp().toISOString();
    }

    private async readForUpdate(ctx: Context, id: string): Promise<LetterOfCredit> {
        checkId(id);
        return JSON.parse(await this.ReadLC(ctx, id)) as LetterOfCredit;
    }

    private requireBank(ctx: Context, bank: string, action: string): void {
        const caller = ctx.clientIdentity.getMSPID();
        if (caller !== bank) {
            throw new Error(
                `${caller} may not ${action} letter of credit; only ${bank} may`,
            );
        }
    }

    private move(ctx: Context, lc: LetterOfCredit, from: LCStatus, to: LCStatus): void {
        if (lc.status !== from) {
            throw new Error(
                `letter of credit ${lc.id} is ${lc.status}; ` +
                    `it must be ${from} to become ${to}`,
            );
        }
        lc.status = to;
        lc.updatedAt = this.txTime(ctx);
    }

    /** Deterministic JSON: one object always gives the same bytes on every endorser. */
    private async save(ctx: Context, lc: LetterOfCredit): Promise<void> {
        await ctx.stub.putState(lc.id, Buffer.from(stringify(sortKeysRecursive(lc))));
    }

    private emit(ctx: Context, name: string, lc: LetterOfCredit): void {
        const payload = {
            id: lc.id,
            status: lc.status,
            issuingBank: lc.issuingBank,
            advisingBank: lc.advisingBank,
            amount: lc.amount,
            currency: lc.currency,
        };
        ctx.stub.setEvent(name, Buffer.from(stringify(sortKeysRecursive(payload))));
    }

    /** A page of results; the peer may leave metadata out when nothing matched. */
    private page(
        records: unknown[],
        metadata?: {fetchedRecordsCount?: number; bookmark?: string},
    ): string {
        return JSON.stringify({
            records,
            fetchedRecordsCount: metadata?.fetchedRecordsCount ?? records.length,
            bookmark: metadata?.bookmark
                ? Buffer.from(metadata.bookmark, 'utf8').toString('base64url')
                : '',
        });
    }

    private decodeBookmark(bookmark: string): string {
        return Buffer.from(bookmark, 'base64url').toString('utf8');
    }

    private pageSize(pageSize: string): number {
        const n = Number(pageSize);
        if (!Number.isInteger(n) || n < 1 || n > 100) {
            throw new Error('pageSize must be an integer from 1 to 100');
        }
        return n;
    }
}
