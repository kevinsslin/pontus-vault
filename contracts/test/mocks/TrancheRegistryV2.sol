// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";

contract TrancheRegistryV2 is TrancheRegistry {
    function version() external pure returns (uint256) {
        return 2;
    }
}
