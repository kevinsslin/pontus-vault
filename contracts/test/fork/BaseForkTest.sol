// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

abstract contract BaseForkTest is Test {
    uint256 internal constant PHAROS_ATLANTIC_FORK_BLOCK_NUMBER = 12_950_000;

    function _forkRpc() internal view returns (string memory _rpc) {
        return vm.envOr("PHAROS_ATLANTIC_RPC_URL", string(""));
    }

    function _createForkOrSkip(string memory _skip_log) internal returns (bool _created) {
        string memory rpc = _forkRpc();
        if (bytes(rpc).length == 0) {
            emit log(_skip_log);
            return false;
        }

        vm.selectFork(vm.createFork(rpc, PHAROS_ATLANTIC_FORK_BLOCK_NUMBER));

        return true;
    }
}
