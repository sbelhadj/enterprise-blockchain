/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Listing 3.8: write a key, then read it back in the same transaction.
 * Deployed only for this experiment; it is not part of the letter of credit chaincode.
 */
'use strict';
const {Contract} = require('fabric-contract-api');

class ProbeContract extends Contract {
    async ReadYourWrite(ctx, key) {
        const before = await ctx.stub.getState(key);
        await ctx.stub.putState(
            key,
            Buffer.from(`written by ${ctx.stub.getTxID().slice(0, 8)}`),
        );
        const after = await ctx.stub.getState(key);
        return JSON.stringify({
            thisTx: ctx.stub.getTxID().slice(0, 8),
            readBeforePut: Buffer.from(before).toString('utf8'),
            readAfterPut: Buffer.from(after).toString('utf8'),
        });
    }
}

module.exports.contracts = [ProbeContract];
