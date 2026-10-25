/*
 * SPDX-License-Identifier: Apache-2.0
 */
import {type Contract} from 'fabric-contract-api';
import {ShipmentContract} from './shipmentContract';

export {ShipmentContract} from './shipmentContract';
export const contracts: (typeof Contract)[] = [ShipmentContract];
