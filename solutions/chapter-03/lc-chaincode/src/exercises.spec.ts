/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Book 4, Appendix A: tests for the solutions to Exercises 3.1 to 3.3.
 */
import {expect} from 'chai';
import {BENEFICIARY_INDEX, LetterOfCreditContract} from './lcContract';
import {LetterOfCredit} from './letterOfCredit';
import {context, FakeIdentity, FakeStub} from './test-support/fakes';

const EXPORT_BANK = 'Org1MSP';
const IMPORT_BANK = 'Org2MSP';

describe('Version 1.2 (Appendix A, Exercises 3.1 to 3.3)', () => {
    let contract: LetterOfCreditContract;
    let stub: FakeStub;
    const officer = new FakeIdentity(IMPORT_BANK, {'lc.role': 'issuer'});
    const importBank = new FakeIdentity(IMPORT_BANK);
    const exportBank = new FakeIdentity(EXPORT_BANK);
    const other = new FakeIdentity('Org3MSP');

    const issue = (id: string, beneficiary = 'Sfax Olive Oil Co', amount = '125000000') =>
        contract.IssueLC(
            context(stub, officer),
            id,
            'Tunis Olive Imports',
            beneficiary,
            EXPORT_BANK,
            amount,
            'EUR',
            '2027-03-31',
            '20 t extra virgin olive oil',
        );
    const read = async (id: string) =>
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
    type Page = {records: LetterOfCredit[]; bookmark: string};

    beforeEach(() => {
        contract = new LetterOfCreditContract();
        stub = new FakeStub();
    });

    describe('RejectLC (3.1)', () => {
        it('lets the advising bank reject an ISSUED LC, with a reason and an event', async () => {
            await issue('LC1');
            await contract.RejectLC(context(stub, exportBank), 'LC1', 'goods not eligible');
            expect(await read('LC1')).to.include({
                status: 'REJECTED',
                rejectionReason: 'goods not eligible',
            });
            expect(stub.events.at(-1)?.name).to.equal('LCRejected');
        });

        it('refuses the issuing bank and any other organization', async () => {
            await issue('LC1');
            await fails(
                contract.RejectLC(context(stub, importBank), 'LC1', 'no'),
                /Org2MSP may not reject .*only Org1MSP may/,
            );
            await fails(
                contract.RejectLC(context(stub, other), 'LC1', 'no'),
                /Org3MSP may not reject/,
            );
        });

        it('refuses an LC that is no longer ISSUED, and an empty reason', async () => {
            await issue('LC1');
            await fails(
                contract.RejectLC(context(stub, exportBank), 'LC1', ' '),
                /reason must be between 1 and 256/,
            );
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            await fails(
                contract.RejectLC(context(stub, exportBank), 'LC1', 'too late'),
                /is ACCEPTED; it must be ISSUED to become REJECTED/,
            );
        });
    });

    describe('AmendLC (3.1)', () => {
        it('changes the amount, the expiry date or both, and emits LCAmended', async () => {
            await issue('LC1');
            stub.now = new Date('2026-11-01T09:00:00.000Z');
            await contract.AmendLC(context(stub, importBank), 'LC1', '130000000', '');
            expect(await read('LC1')).to.include({
                amount: 130000000,
                expiryDate: '2027-03-31',
                updatedAt: '2026-11-01T09:00:00.000Z',
            });
            await contract.AmendLC(context(stub, importBank), 'LC1', '', '2027-06-30');
            await contract.AmendLC(context(stub, importBank), 'LC1', '1', '2027-07-31');
            expect(await read('LC1')).to.include({amount: 1, expiryDate: '2027-07-31'});
            expect(stub.events.at(-1)?.name).to.equal('LCAmended');
        });

        it('lets only the issuing bank amend', async () => {
            await issue('LC1');
            await fails(
                contract.AmendLC(context(stub, exportBank), 'LC1', '1', ''),
                /Org1MSP may not amend .*only Org2MSP may/,
            );
        });

        it('refuses an empty amendment, bad values and an LC past ISSUED', async () => {
            await issue('LC1');
            await fails(
                contract.AmendLC(context(stub, importBank), 'LC1', '', ''),
                /nothing to amend/,
            );
            await fails(
                contract.AmendLC(context(stub, importBank), 'LC1', '-5', ''),
                /invalid amount/,
            );
            await fails(
                contract.AmendLC(context(stub, importBank), 'LC1', '', '2026-01-01'),
                /is not after the transaction date/,
            );
            await contract.AcceptLC(context(stub, exportBank), 'LC1');
            await fails(
                contract.AmendLC(context(stub, importBank), 'LC1', '1', ''),
                /is ACCEPTED; only an ISSUED LC can be amended/,
            );
        });
    });

    describe('GetLCsByBeneficiary (3.2)', () => {
        it('indexes each new LC by beneficiary and pages through one beneficiary', async () => {
            for (const id of ['A1', 'A2', 'A3']) {
                await issue(id, 'Sfax Olive Oil Co');
            }
            for (const id of ['B1', 'B2']) {
                await issue(id, 'Nabeul Ceramics');
            }
            expect(
                stub.state.has(
                    stub.createCompositeKey(BENEFICIARY_INDEX, ['Nabeul Ceramics', 'B1']),
                ),
            ).to.equal(true);
            const page = async (bookmark: string) =>
                JSON.parse(
                    await contract.GetLCsByBeneficiary(
                        context(stub, exportBank),
                        'Sfax Olive Oil Co',
                        '2',
                        bookmark,
                    ),
                ) as Page;
            const p1 = await page('');
            const p2 = await page(p1.bookmark);
            expect(p1.records.map((r) => r.id)).to.deep.equal(['A1', 'A2']);
            expect(p2.records.map((r) => r.id)).to.deep.equal(['A3']);
            expect(p2.bookmark).to.equal('');
        });
    });

    describe('GetLCsAboveAmount (3.3)', () => {
        it('selects LCs strictly above the amount, through the amount index', async () => {
            await issue('S', undefined, '5000000');
            await issue('M', undefined, '100000000');
            await issue('L', undefined, '900000000');
            const result = JSON.parse(
                await contract.GetLCsAboveAmount(
                    context(stub, exportBank),
                    '100000000',
                    '10',
                    '',
                ),
            ) as Page;
            expect(result.records.map((r) => r.id)).to.deep.equal(['L']);
        });

        it('rejects an amount that is not a positive integer', async () => {
            await fails(
                contract.GetLCsAboveAmount(context(stub, exportBank), '1e6', '10', ''),
                /invalid amount/,
            );
        });
    });
});
