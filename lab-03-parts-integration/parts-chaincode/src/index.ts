/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {type Contract} from 'fabric-contract-api';
import {PartsContract} from './partsContract';

export {PartsContract} from './partsContract';
export const contracts: (typeof Contract)[] = [PartsContract];
