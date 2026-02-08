// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

abstract contract BaseForkTest is Test {
    uint256 internal constant PHAROS_ATLANTIC_FORK_BLOCK_NUMBER = 12_950_000;

    function _forkRpc() internal view returns (string memory _rpc) {
        _rpc = vm.envString("PHAROS_ATLANTIC_RPC_URL");
        require(bytes(_rpc).length != 0, "PHAROS_ATLANTIC_RPC_URL is empty");
    }

    function _createFork() internal {
        vm.selectFork(vm.createFork(_forkRpc(), PHAROS_ATLANTIC_FORK_BLOCK_NUMBER));
    }
}
