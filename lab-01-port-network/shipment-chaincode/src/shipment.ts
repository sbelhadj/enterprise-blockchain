/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The shipment record of the port community network and the events that move it.
 */

export enum Status {
    MANIFESTED = 'MANIFESTED',
    ARRIVED = 'ARRIVED',
    DISCHARGED = 'DISCHARGED',
    HELD = 'HELD',
    RELEASED = 'RELEASED',
    PICKUP_BOOKED = 'PICKUP_BOOKED',
    GATED_OUT = 'GATED_OUT',
}

export interface Shipment {
    docType: 'shipment';
    id: string;
    containerNo: string;
    vessel: string;
    portOfLoading: string;
    consignee: string;
    status: Status;
    updatedBy: string;
    updatedAt: string;
}

/** Who may record each event, and from which states. Everything else is refused. */
export const EVENTS: Record<string, {by: string; from: Status[]; to: Status}> = {
    ARRIVE: {by: 'ShippingLineMSP', from: [Status.MANIFESTED], to: Status.ARRIVED},
    DISCHARGE: {
        by: 'PortTerminalMSP',
        from: [Status.ARRIVED],
        to: Status.DISCHARGED,
    },
    HOLD: {by: 'CustomsMSP', from: [Status.DISCHARGED], to: Status.HELD},
    RELEASE: {
        by: 'CustomsMSP',
        from: [Status.DISCHARGED, Status.HELD],
        to: Status.RELEASED,
    },
    BOOK_PICKUP: {
        by: 'FreightForwarderMSP',
        from: [Status.RELEASED],
        to: Status.PICKUP_BOOKED,
    },
    GATE_OUT: {
        by: 'PortTerminalMSP',
        from: [Status.RELEASED, Status.PICKUP_BOOKED],
        to: Status.GATED_OUT,
    },
};

/** ISO 6346 layout: owner code, category (U, J or Z), serial, check digit. */
export const CONTAINER_NO = /^[A-Z]{3}[UJZ]\d{7}$/;
export const ID = /^[A-Za-z0-9_-]{1,64}$/;
