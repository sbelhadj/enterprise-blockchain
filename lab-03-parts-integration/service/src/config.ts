/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Where the service finds the network, its identities and its own data. Everything
 * secret lives in folders that Git ignores: wallet/, .secrets/ and data/.
 */
import * as path from 'node:path';

const SERVICE = path.resolve(__dirname, '..');
const ORGS = path.resolve(SERVICE, '../build/organizations');

export const config = {
    channel: 'partschannel',
    chaincode: 'parts',
    listen: {host: '127.0.0.1', port: Number(process.env.PORT ?? 3000)},
    wallet: path.join(SERVICE, 'wallet'),
    users: path.join(SERVICE, '.secrets/api-users.json'),
    database: path.join(SERVICE, 'data/maintenance.db'),
    checkpoint: path.join(SERVICE, 'data/checkpoint.json'),
    /** The identity the listener and reconciliation use: a service account. */
    serviceUser: 'maintsync',
    ui: path.join(SERVICE, 'src/ui.html'),
};

/** Each organization's own peer: a user always connects through it. */
export const orgs: Record<string, {msp: string; peer: string; tlsRoot: string}> = {
    partsmaker: {
        msp: 'PartsMakerMSP',
        peer: 'localhost:7051',
        tlsRoot: path.join(ORGS, 'partsmaker/msp/tlscacerts/tlsca.pem'),
    },
    mro: {
        msp: 'MROMSP',
        peer: 'localhost:8051',
        tlsRoot: path.join(ORGS, 'mro/msp/tlscacerts/tlsca.pem'),
    },
    airline: {
        msp: 'AirlineMSP',
        peer: 'localhost:9051',
        tlsRoot: path.join(ORGS, 'airline/msp/tlscacerts/tlsca.pem'),
    },
};
