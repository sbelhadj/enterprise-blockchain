/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {type Contract} from 'fabric-contract-api';
import {PharmaTraceContract} from './pharmaTraceContract';

export {PharmaTraceContract} from './pharmaTraceContract';
export const contracts: (typeof Contract)[] = [PharmaTraceContract];
