// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract AssetoForkTest is Test {
    function testAssetoProduct_readOnlySmokeOnPharos() external {
        string memory rpc = vm.envOr("PHAROS_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log(TestDefaults.LOG_SKIP_ASSETO_FORK);
            return;
        }

        vm.selectFork(vm.createFork(rpc));

        IAssetoProduct assetoProduct = IAssetoProduct(TestConstants.ASSETO_CASH_PLUS);
        uint256 price = assetoProduct.getPrice();
        assetoProduct.paused();

        assertGt(price, 0);
    }
}
