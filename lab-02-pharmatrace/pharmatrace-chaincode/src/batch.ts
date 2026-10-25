/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * A batch of a serialized prescription medicine, as PharmaTrace records it.
 * No patient data: a dispensed unit is a serial number, never a person.
 */

export enum Status {
    PRODUCED = 'PRODUCED',
    SHIPPED = 'SHIPPED',
    RECEIVED = 'RECEIVED',
    DISPENSED = 'DISPENSED',
    RECALLED = 'RECALLED',
}

export interface Batch {
    docType: 'batch';
    id: string;
    gtin: string;
    product: string;
    serials: string[];
    dispensed: string[];
    status: Status;
    holder: string; // MSP ID of the organization that has custody
    shippedTo: string; // MSP ID of the receiver while SHIPPED, otherwise ''
    recallReason: string;
    updatedBy: string;
    updatedAt: string;
}

/** Who may ship to whom: the custody chain of the scenario. */
export const NEXT_HOLDER: Record<string, string> = {
    ManufacturerMSP: 'DistributorMSP',
    DistributorMSP: 'PharmacyMSP',
};

export const RECALLERS = ['RegulatorMSP', 'ManufacturerMSP'];
export const TERMS = 'mfrDistTerms'; // collection of the two trading partners
export const SERIAL_INDEX = 'serial~batch';
export const ID = /^[A-Za-z0-9_-]{1,64}$/;
export const SERIAL = /^[A-Za-z0-9]{1,20}$/;

/** GS1 check digit: weights 3 and 1 from the right, excluding the check digit. */
export function validGtin(gtin: string): boolean {
    if (!/^\d{14}$/.test(gtin)) {
        return false;
    }
    const sum = [...gtin.slice(0, 13)]
        .reverse()
        .reduce((s, d, i) => s + Number(d) * (i % 2 === 0 ? 3 : 1), 0);
    return (10 - (sum % 10)) % 10 === Number(gtin[13]);
}
