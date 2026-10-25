/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L3.3: maps API users to Fabric identities. An API key proves who calls
 * the service; the user's own certificate and key, enrolled with Fabric CA, sign
 * what they submit, so the ledger records the person's organization, not the
 * service's.
 */
import {createHash, timingSafeEqual} from 'node:crypto';
import {promises as fs} from 'node:fs';
import * as path from 'node:path';

export interface ApiUser {
    user: string;
    org: string;
    keyHash: string; // SHA-256 of the API key, hex; the key itself is never stored
}

export interface FabricIdentity {
    credentials: Buffer;
    privateKeyPem: Buffer;
}

export const sha256 = (s: string): string =>
    createHash('sha256').update(s).digest('hex');

/** The user whose key matches the bearer token, or undefined. */
export function authenticate(
    users: ApiUser[],
    header?: string,
): ApiUser | undefined {
    const m = /^Bearer ([A-Za-z0-9]{16,128})$/.exec(header ?? '');
    if (!m) {
        return undefined;
    }
    const presented = Buffer.from(sha256(m[1]), 'hex');
    return users.find((u) => {
        const stored = Buffer.from(u.keyHash, 'hex');
        return (
            stored.length === presented.length && timingSafeEqual(stored, presented)
        );
    });
}

export async function loadUsers(file: string): Promise<ApiUser[]> {
    return JSON.parse(await fs.readFile(file, 'utf8')) as ApiUser[];
}

/** Reads a wallet entry; refuses a key that other local accounts can read. */
export async function loadIdentity(
    wallet: string,
    user: string,
): Promise<FabricIdentity> {
    const dir = path.join(wallet, user);
    const key = path.join(dir, 'key.pem');
    const mode = (await fs.stat(key)).mode & 0o777;
    if (mode & 0o077) {
        throw new Error(`${key} is readable by others (mode ${mode.toString(8)})`);
    }
    return {
        credentials: await fs.readFile(path.join(dir, 'cert.pem')),
        privateKeyPem: await fs.readFile(key),
    };
}
