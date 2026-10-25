/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {type Contract} from 'fabric-contract-api';
import {LetterOfCreditContract} from './lcContract';

export {LetterOfCreditContract} from './lcContract';
export const contracts: (typeof Contract)[] = [LetterOfCreditContract];
