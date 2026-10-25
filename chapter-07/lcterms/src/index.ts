/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {type Contract} from 'fabric-contract-api';
import {LCTermsContract} from './termsContract';

export {LCTermsContract} from './termsContract';
export const contracts: (typeof Contract)[] = [LCTermsContract];
