/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing L3.4: the REST API. Every request is authenticated with an API key and
 * runs under the caller's own Fabric identity. The routes match openapi.yaml.
 */
import express, {NextFunction, Request, Response} from 'express';
import {promises as fs} from 'node:fs';
import {config} from './config';
import {MaintenanceDb} from './db';
import {toHttp} from './errors';
import {ApiUser, authenticate} from './identity';

/** What the routes need from the ledger; the tests pass a fake. */
export interface LedgerPort {
    evaluate(user: ApiUser, fn: string, ...args: string[]): Promise<unknown>;
    submit(
        user: ApiUser,
        fn: string,
        ...args: string[]
    ): Promise<{result: {txId: string; block: number}; attempts: number}>;
    transactionStatus(user: ApiUser, txId: string): Promise<unknown>;
}

type Handler = (req: Request, res: Response) => Promise<void>;

export function createApp(
    ledger: LedgerPort,
    users: ApiUser[],
    db?: MaintenanceDb,
) {
    const app = express();
    app.use(express.json({limit: '16kb'}));

    // The history page is public; its data calls are not.
    app.get('/', (_req, res) => {
        void fs
            .readFile(config.ui, 'utf8')
            .then((html) => res.type('html').send(html));
    });

    app.use((req: Request, res: Response, next: NextFunction) => {
        const user = authenticate(users, req.get('authorization'));
        if (!user) {
            res.status(401).json({error: 'missing or invalid API key'});
            return;
        }
        res.locals.user = user;
        next();
    });

    const as = (res: Response) => res.locals.user as ApiUser;
    const str = (v: unknown) => (typeof v === 'string' ? v : '');
    const route = (h: Handler) => (req: Request, res: Response) => {
        h(req, res).catch((e: unknown) => {
            const {status, body} = toHttp(e);
            if (status >= 500) {
                const d = (e as {details?: {message?: string}[]}).details ?? [];
                console.error(
                    `[api] ${status} ${String(e)}`,
                    d.map((x) => x.message),
                );
            }
            res.status(status).json(body);
        });
    };
    const submitted = (
        res: Response,
        status: number,
        r: Awaited<ReturnType<LedgerPort['submit']>>,
    ) => {
        res.status(status).json({...r.result, attempts: r.attempts});
    };

    app.get(
        '/parts/:serial',
        route(async (req, res) => {
            res.json(
                await ledger.evaluate(
                    as(res),
                    'ReadPart',
                    req.params.serial as string,
                ),
            );
        }),
    );

    app.get(
        '/parts/:serial/history',
        route(async (req, res) => {
            res.json(
                await ledger.evaluate(
                    as(res),
                    'GetHistory',
                    req.params.serial as string,
                ),
            );
        }),
    );

    app.post(
        '/parts',
        route(async (req, res) => {
            const b = (req.body ?? {}) as Record<string, unknown>;
            const r = await ledger.submit(
                as(res),
                'RegisterPart',
                str(b.serial),
                str(b.partNumber),
                str(b.description),
                str(b.certHash),
            );
            submitted(res, 201, r);
        }),
    );

    app.post(
        '/parts/:serial/events',
        route(async (req, res) => {
            const b = (req.body ?? {}) as Record<string, unknown>;
            const r = await ledger.submit(
                as(res),
                'RecordEvent',
                req.params.serial as string,
                str(b.type),
                str(b.aircraft),
                str(b.position),
                str(b.docHash),
            );
            submitted(res, 200, r);
        }),
    );

    app.post(
        '/parts/:serial/cycles',
        route(async (req, res) => {
            const b = (req.body ?? {}) as Record<string, unknown>;
            const r = await ledger.submit(
                as(res),
                'RecordCycles',
                req.params.serial as string,
                typeof b.cycles === 'number' ? String(b.cycles) : str(b.cycles),
            );
            submitted(res, 200, r);
        }),
    );

    app.get(
        '/transactions/:txId',
        route(async (req, res) => {
            res.json(
                await ledger.transactionStatus(as(res), req.params.txId as string),
            );
        }),
    );

    // The maintenance system's view, from its own database
    app.get('/maintenance/parts', (_req, res) => {
        res.json(db ? db.parts() : []);
    });

    return app;
}
