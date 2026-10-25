/*
 * SPDX-License-Identifier: Apache-2.0
 */
import 'reflect-metadata';
import {expect} from 'chai';
import {contracts, LetterOfCreditContract} from './index';
import {LCStatus, LetterOfCredit} from './letterOfCredit';

describe('package entry point and data type', () => {
    it('exports the contract for fabric-chaincode-node', () => {
        expect(contracts).to.deep.equal([LetterOfCreditContract]);
    });

    it('creates an empty LetterOfCredit in the ISSUED state', () => {
        const lc = new LetterOfCredit();
        expect(lc).to.include({
            docType: 'lc',
            amount: 0,
            status: LCStatus.ISSUED,
            documentsHash: '',
        });
    });
});

describe('contract metadata', () => {
    it('gives every LetterOfCredit property a concrete design type', () => {
        // Without an explicit annotation, TypeScript records the type Object, and the chaincode
        // fails at start-up with "can't resolve reference Object" (Common Mistakes, Chapter 3).
        for (const key of Object.keys(new LetterOfCredit())) {
            const type = Reflect.getMetadata(
                'design:type',
                LetterOfCredit.prototype,
                key,
            ) as unknown;
            expect(type, key).to.be.oneOf([String, Number]);
        }
    });
});
