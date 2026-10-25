/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Starts the service: the API on 127.0.0.1 only, and the event listener that keeps
 * the maintenance database in step with the ledger.
 */
import {mkdirSync} from 'node:fs';
import * as path from 'node:path';
import {createApp} from './api';
import {config} from './config';
import {MaintenanceDb} from './db';
import {Ledger} from './fabric';
import {loadUsers} from './identity';
import {runListener} from './listener';

async function main(): Promise<void> {
    mkdirSync(path.dirname(config.database), {recursive: true, mode: 0o700});
    const db = new MaintenanceDb(config.database);
    const ledger = new Ledger();
    const users = await loadUsers(config.users);
    const log = (line: string) => console.log(`[listener] ${line}`);
    const stop = await runListener(
        await ledger.network({user: config.serviceUser, org: 'airline'}),
        db,
        log,
    );
    const server = createApp(ledger, users, db).listen(
        config.listen.port,
        config.listen.host,
        () =>
            console.log(
                `[api] listening on ${config.listen.host}:${config.listen.port}`,
            ),
    );
    const shutdown = () => {
        stop();
        server.close();
        ledger.close();
        db.close();
        console.log('[api] stopped');
    };
    process.once('SIGTERM', shutdown);
    process.once('SIGINT', shutdown);
}

main().catch((e: unknown) => {
    console.error(e);
    process.exitCode = 1;
});
