/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Part E: a short load run through the API, open loop as in Chapter 8.
 * Every request adds one flight cycle to the same part, so concurrent requests
 * collide on one key: this measures the service's MVCC retries, not raw throughput.
 *   KEY=... npm run load -- SERIAL RATE SECONDS
 */
const [serial = 'ESN-1001', rate = '5', seconds = '10'] = process.argv.slice(2);
const url = `http://127.0.0.1:${process.env.PORT ?? 3000}/parts/${serial}/cycles`;

interface Result {
    status: number;
    ms: number;
    attempts: number;
    error: string;
}

async function one(): Promise<Result> {
    const t0 = performance.now();
    const res = await fetch(url, {
        method: 'POST',
        headers: {
            authorization: `Bearer ${process.env.KEY ?? ''}`,
            'content-type': 'application/json',
        },
        body: JSON.stringify({cycles: 1}),
    });
    const body = (await res.json()) as {attempts?: number; error?: string};
    return {
        status: res.status,
        ms: performance.now() - t0,
        attempts: body.attempts ?? 0,
        error: body.error ?? '',
    };
}

async function main(): Promise<void> {
    const total = Number(rate) * Number(seconds);
    const runs: Promise<Result>[] = [];
    const t0 = performance.now();
    for (let i = 0; i < total; i++) {
        const wait = t0 + (i * 1000) / Number(rate) - performance.now();
        if (wait > 1) {
            await new Promise((r) => setTimeout(r, wait));
        }
        runs.push(one());
    }
    const results = await Promise.all(runs);
    const byStatus = new Map<string, number>();
    for (const r of results) {
        const k = r.error ? `${r.status} ${r.error}` : String(r.status);
        byStatus.set(k, (byStatus.get(k) ?? 0) + 1);
    }
    const ok = results.filter((r) => r.status === 200);
    const ms = ok.map((r) => r.ms).sort((a, b) => a - b);
    const pct = (p: number) =>
        ms.length ? ms[Math.min(ms.length - 1, Math.floor(p * ms.length))] : NaN;
    const retried = ok.filter((r) => r.attempts > 1).length;
    console.log(`${total} requests at ${rate}/s to one part over ${seconds} s:`);
    console.log([...byStatus].map(([s, n]) => `  ${n} x ${s}`).join('\n'));
    console.log(
        `committed after a retry: ${retried}; ` +
            `latency p50 ${pct(0.5).toFixed(0)} ms, p95 ${pct(0.95).toFixed(0)} ms`,
    );
}

main().catch((e: unknown) => {
    console.error(e);
    process.exitCode = 1;
});
