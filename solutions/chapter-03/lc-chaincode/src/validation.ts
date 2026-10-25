/*
 * SPDX-License-Identifier: Apache-2.0
 */

/** Input checks shared by the contract functions. Each throws a message for the client. */

const ID = /^[A-Za-z0-9_-]{1,64}$/;
const AMOUNT = /^[1-9][0-9]{0,14}$/; // positive, at most 15 digits: exact in a JS number
const CURRENCY = /^[A-Z]{3}$/;
const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const SHA256 = /^[0-9a-f]{64}$/;

export function checkId(id: string): void {
    if (!ID.test(id)) {
        throw new Error(`invalid LC id "${id}": use 1 to 64 letters, digits, - or _`);
    }
}

export function parseAmount(amount: string): number {
    if (!AMOUNT.test(amount)) {
        throw new Error(
            `invalid amount "${amount}": give a positive integer number of minor units`,
        );
    }
    return Number(amount);
}

export function checkCurrency(currency: string): void {
    if (!CURRENCY.test(currency)) {
        throw new Error(`invalid currency "${currency}": use a three-letter ISO 4217 code`);
    }
}

/** The expiry date must be a real calendar date after the transaction's own date. */
export function checkExpiry(expiryDate: string, txDate: string): void {
    if (
        !DATE.test(expiryDate) ||
        new Date(`${expiryDate}T00:00:00Z`).toISOString().slice(0, 10) !== expiryDate
    ) {
        throw new Error(`invalid expiry date "${expiryDate}": use YYYY-MM-DD`);
    }
    if (expiryDate <= txDate) {
        throw new Error(
            `expiry date ${expiryDate} is not after the transaction date ${txDate}`,
        );
    }
}

export function checkText(field: string, value: string, max: number): void {
    if (value.trim().length === 0 || value.length > max) {
        throw new Error(`${field} must be between 1 and ${max} characters`);
    }
}

export function checkHash(hash: string): void {
    if (!SHA256.test(hash)) {
        throw new Error('documentsHash must be a lowercase hex SHA-256 digest');
    }
}
