// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseForkTest} from "./BaseForkTest.sol";

contract AssetoForkTest is BaseForkTest {
    function test_asseto_product_read_only_smoke_on_pharos() external {
        if (!_createForkOrSkip(TestDefaults.LOG_SKIP_ASSETO_FORK)) return;

        IAssetoProduct assetoProduct = IAssetoProduct(TestConstants.PHAROS_ATLANTIC_ASSETO_CASH_PLUS);
        uint256 price = assetoProduct.getPrice();
        assetoProduct.paused();

        assertGt(price, 0);
    }
}
