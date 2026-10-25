/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L3.9: reconciliation. Compares the maintenance database with the ledger,
 * part by part, and reports every difference. With --fix the ledger wins, because
 * the ledger is the record the three organizations agreed on.
 *   npm run reconcile [-- --fix]
 */
import {config} from './config';
import {MaintenanceDb, PartRow} from './db';
import {Ledger} from './fabric';

interface LedgerPart {
    serial: string;
    partNumber: string;
    status: string;
    aircraft: string;
    position: string;
    cycles: number;
}

const FIELDS = ['status', 'aircraft', 'position', 'cycles'] as const;

export function compare(db: PartRow[], ledger: LedgerPart[]) {
    const rows = new Map(db.map((r) => [r.serial, r]));
    const differences: string[] = [];
    for (const p of ledger) {
        const r = rows.get(p.serial);
        if (!r) {
            differences.push(`${p.serial}: on the ledger, missing in the database`);
            continue;
        }
        for (const f of FIELDS) {
            if (String(r[f]) !== String(p[f])) {
                const show = (v: unknown) => (v === '' ? '(none)' : String(v));
                differences.push(
                    `${p.serial}: ${f} is ${show(r[f])} here, ` +
                        `${show(p[f])} on the ledger`,
                );
            }
        }
        rows.delete(p.serial);
    }
    for (const serial of rows.keys()) {
        differences.push(`${serial}: in the database, not on the ledger`);
    }
    return {checked: ledger.length, differences};
}

async function main(): Promise<void> {
    const fix = process.argv.includes('--fix');
    const db = new MaintenanceDb(config.database);
    const ledger = new Ledger();
    try {
        const parts = (await ledger.evaluate(
            {user: config.serviceUser, org: 'airline', keyHash: ''},
            'ListParts',
        )) as LedgerPart[];
        const result = compare(db.parts(), parts);
        console.log(
            `parts on the ledger: ${result.checked}, ` +
                `differences: ${result.differences.length}`,
        );
        result.differences.forEach((d) => console.log(`  ${d}`));
        if (fix && result.differences.length > 0) {
            for (const p of parts) {
                const {serial, partNumber, status, aircraft, position, cycles} = p;
                db.overwrite({
                    serial,
                    part_number: partNumber,
                    status,
                    aircraft,
                    position,
                    cycles,
                    last_tx: 'reconciled',
                });
            }
            console.log(
                `fixed: the database now matches the ledger for ${parts.length}`,
            );
        }
        process.exitCode = result.differences.length > 0 && !fix ? 1 : 0;
    } finally {
        ledger.close();
        db.close();
    }
}

if (require.main === module) {
    main().catch((e: unknown) => {
        console.error(e);
        process.exitCode = 2;
    });
}
