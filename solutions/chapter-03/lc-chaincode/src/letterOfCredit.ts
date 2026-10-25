/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {Object as DataType, Property} from 'fabric-contract-api';

/** The states a letter of credit moves through (Figure 3.2). */
export const LCStatus = {
    ISSUED: 'ISSUED',
    ACCEPTED: 'ACCEPTED',
    REJECTED: 'REJECTED',
    DOCUMENTS_PRESENTED: 'DOCUMENTS_PRESENTED',
    PAID: 'PAID',
} as const;
export type LCStatus = (typeof LCStatus)[keyof typeof LCStatus];

/**
 * A documentary letter of credit as stored in the world state.
 * Money is an integer number of minor units (cents) with an explicit ISO 4217 currency:
 * floating point would round differently on different endorsers.
 * Every property has an explicit type: the contract API builds its metadata from them.
 */
@DataType()
export class LetterOfCredit {
    @Property() public docType: string = 'lc';
    @Property() public id: string = '';
    @Property() public applicant: string = ''; // the importer, ImportBank's customer
    @Property() public beneficiary: string = ''; // the exporter, ExportBank's customer
    @Property() public issuingBank: string = ''; // MSP ID of the bank that issued the LC
    @Property() public advisingBank: string = ''; // MSP ID of the beneficiary's bank
    @Property() public amount: number = 0; // minor units: 125000000 = 1,250,000.00
    @Property() public currency: string = '';
    @Property() public expiryDate: string = ''; // YYYY-MM-DD
    @Property() public goods: string = '';
    @Property() public documentsHash: string = ''; // SHA-256 of documents kept off-chain
    @Property() public status: string = LCStatus.ISSUED;
    @Property() public rejectionReason: string = ''; // set by RejectLC (version 1.2)
    @Property() public issuedAt: string = ''; // transaction time, never the system clock
    @Property() public updatedAt: string = '';
}
