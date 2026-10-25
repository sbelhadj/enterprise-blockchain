/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Fabric errors in HTTP terms. A client of the API should not need to know what an
 * endorsement is: it needs to know whether to fix its request, retry later, or ask
 * what happened to a transaction whose fate is unknown.
 */

export class UnknownOutcome extends Error {
    constructor(public readonly txId: string) {
        super(
            `transaction ${txId} was submitted, but its commit status is unknown`,
        );
    }
}

export class Conflict extends Error {
    constructor(
        public readonly txId: string,
        public readonly code: string,
    ) {
        super(`transaction ${txId} was not committed: ${code}`);
    }
}

export interface HttpError {
    status: number;
    body: {error: string; detail?: string; txId?: string};
}

interface FabricLikeError {
    name?: string;
    message?: string;
    details?: {message?: string}[];
}

/** The chaincode's own message, as the peers returned it; '' if there is none. */
export function chaincodeMessage(e: FabricLikeError): string {
    const texts = [
        ...(e.details ?? []).map((d) => d.message ?? ''),
        e.message ?? '',
    ];
    for (const t of texts) {
        const m = /chaincode response \d+, (.*)$/.exec(t);
        if (m) {
            return m[1];
        }
    }
    return '';
}

export function toHttp(err: unknown): HttpError {
    if (err instanceof UnknownOutcome) {
        return {
            status: 202,
            body: {error: 'outcome unknown', detail: err.message, txId: err.txId},
        };
    }
    if (err instanceof Conflict) {
        return {
            status: 409,
            body: {error: err.code, detail: err.message, txId: err.txId},
        };
    }
    const e = (err ?? {}) as FabricLikeError;
    const detail = chaincodeMessage(e);
    if (detail !== '') {
        // refused by the contract while endorsing (submit) or evaluating (query)
        const status = /may not/.test(detail)
            ? 403
            : /does not exist/.test(detail)
              ? 404
              : /already exists|is not allowed|only installed/.test(detail)
                ? 409
                : /invalid|must be|unknown event/.test(detail)
                  ? 400
                  : 502;
        return {status, body: {error: 'rejected by the chaincode', detail}};
    }
    if (e.name === 'EndorseError') {
        return {
            status: 502,
            body: {error: 'endorsement failed', detail: e.message},
        };
    }
    if (e.name === 'SubmitError' || e.name === 'GatewayError') {
        return {
            status: 503,
            body: {error: 'ledger unavailable', detail: e.message},
        };
    }
    return {status: 500, body: {error: 'internal error'}};
}
