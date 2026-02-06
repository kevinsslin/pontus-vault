// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";

contract TrancheFactoryV2 is TrancheFactory {
    function version() external pure returns (uint256) {
        return 2;
    }
}
