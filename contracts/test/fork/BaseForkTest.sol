// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

abstract contract BaseForkTest is Test {
    function _forkRpc() internal view returns (string memory _rpc) {
        return vm.envOr("PHAROS_ATLANTIC_RPC_URL", string(""));
    }

    function _forkBlockNumber() internal view returns (string memory _block_number) {
        return vm.envOr("PHAROS_ATLANTIC_FORK_BLOCK_NUMBER", string(""));
    }

    function _createForkOrSkip(string memory _skip_log) internal returns (bool _created) {
        string memory rpc = _forkRpc();
        if (bytes(rpc).length == 0) {
            emit log(_skip_log);
            return false;
        }

        string memory forkBlockNumber = _forkBlockNumber();
        if (bytes(forkBlockNumber).length == 0) {
            vm.selectFork(vm.createFork(rpc));
        } else {
            vm.selectFork(vm.createFork(rpc, vm.parseUint(forkBlockNumber)));
        }

        return true;
    }
}
