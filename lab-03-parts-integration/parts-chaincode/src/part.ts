/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * A serialized aircraft part and the events that change it. Documents such as the
 * authorized release certificate stay in each organization's systems; the ledger
 * keeps their SHA-256 hash, so anyone with a copy can prove it is the one recorded.
 */

export enum Status {
    SERVICEABLE = 'SERVICEABLE',
    INSTALLED = 'INSTALLED',
    UNSERVICEABLE = 'UNSERVICEABLE',
    SCRAPPED = 'SCRAPPED',
}

export interface Part {
    docType: 'part';
    serial: string;
    partNumber: string;
    description: string;
    status: Status;
    aircraft: string; // registration while INSTALLED, otherwise ''
    position: string;
    cycles: number; // flight cycles since new, reported by the operator
    lastDocHash: string; // hash of the latest release certificate
    updatedBy: string;
    updatedAt: string;
}

/** Who may record each event, and from which states. */
export const EVENTS: Record<string, {by: string[]; from: Status[]; to: Status}> = {
    INSTALL: {
        by: ['AirlineMSP', 'MROMSP'],
        from: [Status.SERVICEABLE],
        to: Status.INSTALLED,
    },
    REMOVE: {
        by: ['AirlineMSP', 'MROMSP'],
        from: [Status.INSTALLED],
        to: Status.UNSERVICEABLE,
    },
    REPAIR: {by: ['MROMSP'], from: [Status.UNSERVICEABLE], to: Status.SERVICEABLE},
    SCRAP: {
        by: ['MROMSP', 'AirlineMSP'],
        from: [Status.UNSERVICEABLE],
        to: Status.SCRAPPED,
    },
};

export const SERIAL = /^[A-Z0-9-]{3,32}$/;
export const HASH = /^[0-9a-f]{64}$/;
export const REGISTRATION = /^[A-Z0-9]{1,2}-?[A-Z0-9]{2,5}$/;
