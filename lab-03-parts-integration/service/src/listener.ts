/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L3.7: keeps the maintenance database in step with the ledger. A file
 * checkpointer records the last event processed, so a restart resumes exactly
 * there: nothing is lost while the service is down, and nothing is applied twice.
 */
import {checkpointers, Network} from '@hyperledger/fabric-gateway';
import {config} from './config';
import {LedgerEvent, MaintenanceDb} from './db';

export async function runListener(
    network: Network,
    db: MaintenanceDb,
    log: (line: string) => void,
): Promise<() => void> {
    const checkpoint = await checkpointers.file(config.checkpoint);
    const events = await network.getChaincodeEvents(config.chaincode, {
        checkpoint,
        startBlock: 0n, // used only when there is no checkpoint yet
    });
    const done = (async () => {
        for await (const e of events) {
            const payload = JSON.parse(Buffer.from(e.payload).toString()) as Omit<
                LedgerEvent,
                'txId' | 'block'
            >;
            const applied = db.apply({
                ...payload,
                txId: e.transactionId,
                block: e.blockNumber,
            });
            log(
                `${applied ? 'applied' : 'skipped'} block ${e.blockNumber} ` +
                    `${payload.type} ${payload.part.serial} -> ` +
                    payload.part.status,
            );
            await checkpoint.checkpointChaincodeEvent(e);
        }
    })().catch(() => undefined); // the iterator ends with an error when closed
    return () => {
        events.close();
        void done;
    };
}
