/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {expect} from 'chai';
import {KeyEndorsementPolicy} from 'fabric-shim';
import {ISSUER_INDEX, LetterOfCreditContract} from './lcContract';
import {LetterOfCredit} from './letterOfCredit';
import {context, FakeIdentity, FakeStub} from './test-support/fakes';

// In the test network, Org1 plays ExportBank and Org2 plays ImportBank.
const EXPORT_BANK = 'Org1MSP';
const IMPORT_BANK = 'Org2MSP';
const HASH = 'a'.repeat(64);

describe('LetterOfCreditContract', () => {
    let contract: LetterOfCreditContract;
    let stub: FakeStub;
    const officer = new FakeIdentity(IMPORT_BANK, {'lc.role': 'issuer'});
    const importAdmin = new FakeIdentity(IMPORT_BANK);
    const exportBank = new FakeIdentity(EXPORT_BANK);

    const issue = (
        id = 'LC1',
        overrides: Partial<Record<string, string>> = {},
        who = officer,
    ) => {
        const a = {
            applicant: 'Tunis Olive Imports',
            beneficiary: 'Sfax Olive Oil Co',
            advisingBank: EXPORT_BANK,
            amount: '125000000',
            currency: 'EUR',
            expiryDate: '2027-03-31',
            goods: '20 t extra virgin olive oil',
            ...overrides,
        };
        return contract.IssueLC(
            context(stub, who),
            id,
            a.applicant,
            a.beneficiary,
            a.advisingBank,
            a.amount,
            a.currency,
            a.expiryDate,
            a.goods,
        );
    };
    const read = async (id = 'LC1') =>
        JSON.parse(await contract.ReadLC(context(stub, exportBank), id)) as LetterOfCredit;
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
        contract = new LetterOfCreditContract();
        stub = new FakeStub();
    });

    describe('IssueLC', () => {
        it('stores the LC with the caller as issuing bank and the transaction time', async () => {
            await issue();
            const lc = await read();
            expect(lc).to.include({
                id: 'LC1',
                issuingBank: IMPORT_BANK,
                advisingBank: EXPORT_BANK,
                amount: 125000000,
                currency: 'EUR',
                status: 'ISSUED',
                issuedAt: '2026-10-24T10:00:00.000Z',
                documentsHash: '',
            });
        });

        it('serializes deterministically, with keys in sorted order', async () => {
            await issue();
            const json = (stub.state.get('LC1') as Buffer).toString('utf8');
            const keys = Object.keys(JSON.parse(json) as object);
            expect(keys).to.deep.equal([...keys].sort());
        });

        it('adds an index entry with a non-empty value', async () => {
            await issue();
            const key = stub.createCompositeKey(ISSUER_INDEX, [IMPORT_BANK, 'LC1']);
            expect(stub.state.get(key)?.length).to.equal(1);
        });

        it('requires both banks to endorse later changes to the LC', async () => {
            await issue();
            const policy = new KeyEndorsementPolicy(stub.validationParameters.get('LC1'));
            expect(policy.listOrgs().sort()).to.deep.equal([EXPORT_BANK, IMPORT_BANK]);
        });

        it('emits LCIssued with a summary, not the whole LC', async () => {
            await issue();
            expect(stub.events[0].name).to.equal('LCIssued');
            expect(JSON.parse(stub.events[0].payload)).to.deep.equal({
                advisingBank: EXPORT_BANK,
                amount: 125000000,
                currency: 'EUR',
                id: 'LC1',
                issuingBank: IMPORT_BANK,
                status: 'ISSUED',
            });
        });

        it('refuses a caller without lc.role=issuer', async () => {
            await fails(issue('LC1', {}, importAdmin), /only an LC officer/);
        });

        it('refuses an advising bank equal to the issuing bank or empty', async () => {
            await fails(issue('LC1', {advisingBank: IMPORT_BANK}), /another organization/);
            await fails(issue('LC1', {advisingBank: ' '}), /another organization/);
        });

        it('refuses a duplicate id', async () => {
            await issue();
            await fails(issue(), /already exists/);
        });

        it('validates every input', async () => {
            await fails(issue('bad id!'), /invalid LC id/);
            await fails(issue('LC1', {applicant: ''}), /applicant must be/);
            await fails(
                issue('LC1', {beneficiary: 'x'.repeat(129)}),
                /beneficiary must be/,
            );
            await fails(issue('LC1', {goods: '   '}), /goods must be/);
            await fails(issue('LC1', {currency: 'eur'}), /invalid currency/);
            await fails(issue('LC1', {amount: '12.50'}), /invalid amount/);
            await fails(issue('LC1', {amount: '0'}), /invalid amount/);
            await fails(issue('LC1', {expiryDate: '31/03/2027'}), /invalid expiry date/);
            await fails(issue('LC1', {expiryDate: '2027-02-30'}), /invalid expiry date/);
            await fails(
                issue('LC1', {expiryDate: '2026-10-24'}),
                /is not after the transaction date 2026-10-24/,
            );
        });
    });

    describe('the life of an LC', () => {
        it('moves ISSUED to ACCEPTED to DOCUMENTS_PRESENTED to PAID', async () => {
            await issue();
            stub.now = new Date('2026-11-02T08:30:00.000Z');
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            expect(await read()).to.include({
                status: 'ACCEPTED',
                updatedAt: '2026-11-02T08:30:00.000Z',
            });
            await contract.PresentDocuments(context(stub, exportBank), 'LC1', HASH);
            expect(await read()).to.include({
                status: 'DOCUMENTS_PRESENTED',
                documentsHash: HASH,
            });
            await contract.PayLC(context(stub, officer), 'LC1');
            expect((await read()).status).to.equal('PAID');
            expect(stub.events.map((e) => e.name)).to.deep.equal([
                'LCIssued',
                'LCAccepted',
                'DocumentsPresented',
                'LCPaid',
            ]);
        });

        it('lets only the advising bank accept and present, and only the issuing bank pay', async () => {
            await issue();
            await fails(
                contract.AcceptLC(context(stub, officer), 'LC1'),
                /Org2MSP may not accept letter of credit; only Org1MSP may/,
            );
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            await fails(
                contract.PresentDocuments(context(stub, officer), 'LC1', HASH),
                /may not present documents/,
            );
            await contract.PresentDocuments(context(stub, exportBank), 'LC1', HASH);
            await fails(
                contract.PayLC(context(stub, exportBank), 'LC1'),
                /Org1MSP may not pay/,
            );
        });

        it('enforces the order of the states', async () => {
            await issue();
            await fails(
                contract.PresentDocuments(context(stub, exportBank), 'LC1', HASH),
                /is ISSUED; it must be ACCEPTED/,
            );
            await fails(
                contract.PayLC(context(stub, officer), 'LC1'),
                /is ISSUED; it must be DOCUMENTS_PRESENTED/,
            );
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            await fails(
                contract.AcceptLC(context(stub, exportBank), 'LC1'),
                /is ACCEPTED; it must be ISSUED/,
            );
        });

        it('checks the documents hash before anything else', async () => {
            await fails(
                contract.PresentDocuments(context(stub, exportBank), 'LC1', 'not-a-hash'),
                /SHA-256/,
            );
        });

        it('reports a missing or malformed id on update', async () => {
            await fails(
                contract.AcceptLC(context(stub, exportBank), 'LC404'),
                /LC404 does not exist/,
            );
            await fails(
                contract.AcceptLC(context(stub, exportBank), 'LC 1'),
                /invalid LC id/,
            );
        });
    });

    describe('queries', () => {
        it('LCExists and ReadLC', async () => {
            expect(await contract.LCExists(context(stub, exportBank), 'LC1')).to.equal(
                false,
            );
            await fails(
                contract.ReadLC(context(stub, exportBank), 'LC1'),
                /does not exist/,
            );
            await issue();
            expect(await contract.LCExists(context(stub, exportBank), 'LC1')).to.equal(
                true,
            );
        });

        it('pages through the issuing-bank index with a bookmark', async () => {
            for (const id of ['LC1', 'LC2', 'LC3']) {
                await issue(id);
            }
            const page1 = JSON.parse(
                await contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '2',
                    '',
                ),
            ) as {records: LetterOfCredit[]; fetchedRecordsCount: number; bookmark: string};
            expect(page1.records.map((r) => r.id)).to.deep.equal(['LC1', 'LC2']);
            expect(page1.fetchedRecordsCount).to.equal(2);
            const page2 = JSON.parse(
                await contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '2',
                    page1.bookmark,
                ),
            ) as {records: LetterOfCredit[]; bookmark: string};
            expect(page2.records.map((r) => r.id)).to.deep.equal(['LC3']);
            expect(page2.bookmark).to.equal('');
        });

        it('hands out bookmarks that survive a shell: base64url, no null bytes', async () => {
            for (const id of ['LC1', 'LC2', 'LC3']) {
                await issue(id);
            }
            const page1 = JSON.parse(
                await contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '1',
                    '',
                ),
            ) as {bookmark: string};
            expect(page1.bookmark).to.match(/^[A-Za-z0-9_-]+$/);
            expect(Buffer.from(page1.bookmark, 'base64url').toString()).to.equal(
                stub.createCompositeKey(ISSUER_INDEX, [IMPORT_BANK, 'LC2']),
            );
        });

        it('copes with a page that comes back without metadata', async () => {
            await issue('LC1');
            stub.dropMetadata = true;
            const page = JSON.parse(
                await contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '5',
                    '',
                ),
            ) as {fetchedRecordsCount: number; bookmark: string};
            expect(page).to.include({fetchedRecordsCount: 1, bookmark: ''});
        });

        it('rejects a page size outside 1 to 100', async () => {
            await fails(
                contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '0',
                    '',
                ),
                /pageSize/,
            );
            await fails(
                contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    '101',
                    '',
                ),
                /pageSize/,
            );
            await fails(
                contract.GetLCsByIssuingBank(
                    context(stub, exportBank),
                    IMPORT_BANK,
                    'ten',
                    '',
                ),
                /pageSize/,
            );
        });

        it('queries by status through the rich-query path', async () => {
            await issue('LC1');
            await issue('LC2');
            await contract.AcceptLC(context(stub, exportBank), 'LC2');
            const result = JSON.parse(
                await contract.QueryLCsByStatus(
                    context(stub, exportBank),
                    'ACCEPTED',
                    '10',
                    '',
                ),
            ) as {records: LetterOfCredit[]; bookmark: string};
            expect(result.records.map((r) => r.id)).to.deep.equal(['LC2']);
            await fails(
                contract.QueryLCsByStatus(context(stub, exportBank), 'OPEN', '10', ''),
                /unknown status OPEN/,
            );
        });

        it('returns the history of an LC, newest first', async () => {
            await issue();
            stub.txId = 'tx2';
            stub.now = new Date('2026-11-02T08:30:00.250Z');
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            stub.txId = 'tx3';
            await stub.deleteState('LC1');
            const history = JSON.parse(
                await contract.GetLCHistory(context(stub, exportBank), 'LC1'),
            ) as {txId: string; status: string; timestamp: string}[];
            expect(history.map((h) => `${h.txId}:${h.status}`)).to.deep.equal([
                'tx3:DELETED',
                'tx2:ACCEPTED',
                'tx1:ISSUED',
            ]);
            expect(history[1].timestamp).to.equal('2026-11-02T08:30:00.250Z');
            await fails(
                contract.GetLCHistory(context(stub, exportBank), '../etc'),
                /invalid LC id/,
            );
        });
    });
});
