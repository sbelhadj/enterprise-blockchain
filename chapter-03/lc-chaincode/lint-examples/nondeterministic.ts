/*
 * Deliberately wrong: four ways to make endorsers disagree. `npm run lint:demo` shows the rule
 * catching each one. This file is not part of the chaincode package build.
 */
import * as fs from 'fs';

export function issuedAt(): string {
    return new Date().toISOString();                  // the endorser's clock
}

export function referenceNumber(): string {
    return `LC-${Date.now()}-${Math.random()}`;       // clock and randomness
}

export function feeSchedule(): string {
    return fs.readFileSync(process.env.FEES ?? 'fees.json', 'utf8');   // local files and settings
}
