/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * In-memory stand-ins for the chaincode stub and client identity, enough for unit tests.
 * They mimic the peer's behavior for the calls the contract makes; they do not simulate
 * endorsement, ordering or validation, which Section 3.10 tests on a real network.
 */
import {Context} from 'fabric-contract-api';

interface HistoryEntry {
    txId: string;
    value: Uint8Array;
    isDelete: boolean;
    timestamp: {seconds: number; nanos: number};
}

function iterator<T>(items: T[]) {
    let i = 0;
    return {
        next: async () =>
            i < items.length
                ? {value: items[i++], done: false}
                : {value: undefined as unknown as T, done: true},
        close: async () => undefined,
    };
}

export class FakeStub {
    public state = new Map<string, Buffer>();
    public history = new Map<string, HistoryEntry[]>();
    public events: {name: string; payload: string}[] = [];
    public validationParameters = new Map<string, Uint8Array>();
    public now = new Date('2026-10-24T10:00:00.000Z');
    public txId = 'tx1';

    async getState(key: string): Promise<Uint8Array> {
        return this.state.get(key) ?? Buffer.alloc(0);
    }

    async putState(key: string, value: Uint8Array): Promise<void> {
        this.state.set(key, Buffer.from(value));
        const h = this.history.get(key) ?? [];
        h.push({
            txId: this.txId,
            value: Buffer.from(value),
            isDelete: false,
            timestamp: {
                seconds: Math.floor(this.now.getTime() / 1000),
                nanos: (this.now.getTime() % 1000) * 1e6,
            },
        });
        this.history.set(key, h);
    }

    async deleteState(key: string): Promise<void> {
        this.state.delete(key);
        const h = this.history.get(key) ?? [];
        h.push({
            txId: this.txId,
            value: Buffer.alloc(0),
            isDelete: true,
            timestamp: {seconds: Math.floor(this.now.getTime() / 1000), nanos: 0},
        });
        this.history.set(key, h);
    }

    getDateTimestamp(): Date {
        return this.now;
    }

    getTxID(): string {
        return this.txId;
    }

    createCompositeKey(objectType: string, attributes: string[]): string {
        return `\u0000${objectType}\u0000${attributes.map((a) => `${a}\u0000`).join('')}`;
    }

    splitCompositeKey(key: string): {objectType: string; attributes: string[]} {
        const parts = key.split('\u0000').slice(1, -1);
        return {objectType: parts[0], attributes: parts.slice(1)};
    }

    async getStateByPartialCompositeKeyWithPagination(
        objectType: string,
        attributes: string[],
        pageSize: number,
        bookmark: string,
    ) {
        const prefix = this.createCompositeKey(objectType, attributes);
        const keys = [...this.state.keys()]
            .filter((k) => k.startsWith(prefix))
            .sort()
            .filter((k) => !bookmark || k >= bookmark);
        const page = keys.slice(0, pageSize);
        return {
            iterator: iterator(
                page.map((key) => ({key, value: this.state.get(key) as Buffer})),
            ),
            metadata: this.dropMetadata
                ? undefined
                : {fetchedRecordsCount: page.length, bookmark: keys[pageSize] ?? ''},
        };
    }

    /** Supports equality and $gt, the selectors the contract uses; the bookmark is an offset. */
    async getQueryResultWithPagination(query: string, pageSize: number, bookmark: string) {
        const {selector} = JSON.parse(query) as {selector: Record<string, unknown>};
        const matches = (v: unknown, want: unknown) =>
            typeof want === 'object' && want !== null
                ? (v as number) > (want as {$gt: number}).$gt
                : v === want;
        const docs = [...this.state.entries()]
            .filter(([k]) => !k.startsWith('\u0000'))
            .map(([key, v]) => ({
                key,
                doc: JSON.parse(v.toString('utf8')) as Record<string, unknown>,
                value: v,
            }))
            .filter(({doc}) =>
                Object.entries(selector).every(([f, want]) => matches(doc[f], want)),
            )
            .sort((a, b) => a.key.localeCompare(b.key));
        const start = bookmark ? Number(bookmark) : 0;
        const page = docs.slice(start, start + pageSize);
        return {
            iterator: iterator(page.map(({key, value}) => ({key, value}))),
            metadata: {
                fetchedRecordsCount: page.length,
                bookmark: start + pageSize < docs.length ? String(start + pageSize) : '',
            },
        };
    }

    /** The peer returns history newest first. */
    async getHistoryForKey(key: string) {
        return iterator([...(this.history.get(key) ?? [])].reverse());
    }

    /** Makes the next pagination call return no metadata, as the peer does for an unknown bookmark. */
    public dropMetadata = false;

    async setStateValidationParameter(key: string, ep: Uint8Array): Promise<void> {
        this.validationParameters.set(key, ep);
    }

    setEvent(name: string, payload: Uint8Array): void {
        this.events.push({name, payload: Buffer.from(payload).toString('utf8')});
    }
}

export class FakeIdentity {
    constructor(
        public mspid: string,
        public attrs: Record<string, string> = {},
    ) {}

    getMSPID(): string {
        return this.mspid;
    }

    getAttributeValue(name: string): string | null {
        return this.attrs[name] ?? null;
    }

    assertAttributeValue(name: string, value: string): boolean {
        return this.attrs[name] === value;
    }
}

export function context(stub: FakeStub, identity: FakeIdentity): Context {
    return {stub, clientIdentity: identity} as unknown as Context;
}
