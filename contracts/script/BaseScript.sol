// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";

abstract contract BaseScript is Script {
    error MissingConfig(string key);

    function _envAddress(string memory key, address defaultValue) internal view returns (address) {
        return vm.envOr(key, defaultValue);
    }

    function _envUint(string memory key, uint256 defaultValue) internal view returns (uint256) {
        return vm.envOr(key, defaultValue);
    }

    function _requireAddress(address value, string memory key) internal pure {
        if (value == address(0)) revert MissingConfig(key);
    }
}
