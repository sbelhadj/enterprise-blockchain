/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * The maintenance system's own database, a stand-in for an ERP. Ledger events
 * update it; the transaction ID makes each update idempotent, so an event that
 * arrives twice changes nothing the second time. Uses Node's built-in SQLite.
 */
import {DatabaseSync} from 'node:sqlite';

export interface PartRow {
    serial: string;
    part_number: string;
    status: string;
    aircraft: string;
    position: string;
    cycles: number;
    last_tx: string;
}

export interface LedgerEvent {
    txId: string;
    block: bigint | number;
    type: string;
    part: {
        serial: string;
        partNumber: string;
        status: string;
        aircraft: string;
        position: string;
        cycles: number;
    };
}

export class MaintenanceDb {
    readonly db: DatabaseSync;

    constructor(file: string) {
        this.db = new DatabaseSync(file);
        this.db.exec(`
            CREATE TABLE IF NOT EXISTS parts (
                serial TEXT PRIMARY KEY, part_number TEXT NOT NULL,
                status TEXT NOT NULL, aircraft TEXT NOT NULL,
                position TEXT NOT NULL, cycles INTEGER NOT NULL,
                last_tx TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS applied (
                tx_id TEXT PRIMARY KEY, block INTEGER NOT NULL, type TEXT NOT NULL,
                serial TEXT NOT NULL);`);
    }

    /** Applies one event in one database transaction; false if already applied. */
    apply(e: LedgerEvent): boolean {
        this.db.exec('BEGIN');
        try {
            const r = this.db
                .prepare(
                    `INSERT INTO applied VALUES (?, ?, ?, ?)
                     ON CONFLICT(tx_id) DO NOTHING`,
                )
                .run(e.txId, Number(e.block), e.type, e.part.serial);
            if (r.changes === 1) {
                const p = e.part;
                this.db
                    .prepare(
                        `INSERT INTO parts VALUES (?, ?, ?, ?, ?, ?, ?)
                         ON CONFLICT(serial) DO UPDATE SET status = excluded.status,
                         aircraft = excluded.aircraft, position = excluded.position,
                         cycles = excluded.cycles, last_tx = excluded.last_tx`,
                    )
                    .run(
                        p.serial,
                        p.partNumber,
                        p.status,
                        p.aircraft,
                        p.position,
                        p.cycles,
                        e.txId,
                    );
            }
            this.db.exec('COMMIT');
            return r.changes === 1;
        } catch (err) {
            this.db.exec('ROLLBACK');
            throw err;
        }
    }

    parts(): PartRow[] {
        return this.db
            .prepare('SELECT * FROM parts ORDER BY serial')
            .all() as unknown as PartRow[];
    }

    /** Used only by reconcile --fix: the ledger's version wins. */
    overwrite(row: PartRow): void {
        this.db
            .prepare(
                `INSERT INTO parts VALUES (?, ?, ?, ?, ?, ?, ?)
                 ON CONFLICT(serial) DO UPDATE SET status = excluded.status,
                 aircraft = excluded.aircraft,
                 position = excluded.position, cycles = excluded.cycles`,
            )
            .run(
                row.serial,
                row.part_number,
                row.status,
                row.aircraft,
                row.position,
                row.cycles,
                row.last_tx,
            );
    }

    close(): void {
        this.db.close();
    }
}
