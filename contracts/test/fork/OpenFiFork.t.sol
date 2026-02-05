// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOpenFiPool} from "../../src/interfaces/IOpenFiPool.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";

contract OpenFiForkTest is Test {
    address internal constant POOL = 0xEC86f142E7334d99EEEF2c43298413299D919B30;
    address internal constant USDC = 0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8;

    function testOpenFiSupplyWithdrawRoundtrip() external {
        string memory rpc = vm.envOr("PHAROS_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log("PHAROS_RPC_URL not set; skipping OpenFi fork test.");
            return;
        }

        vm.selectFork(vm.createFork(rpc));

        assertEq(OpenFiCallBuilder.supplySelector(), IOpenFiPool.supply.selector);
        assertEq(OpenFiCallBuilder.withdrawSelector(), IOpenFiPool.withdraw.selector);

        uint256 amount = 1_000e6;
        deal(USDC, address(this), amount);
        IERC20(USDC).approve(POOL, amount);

        (bool ok,) = POOL.call(OpenFiCallBuilder.supplyCalldata(USDC, amount, address(this)));
        assertTrue(ok, "supply failed");

        (ok,) = POOL.call(OpenFiCallBuilder.withdrawCalldata(USDC, amount, address(this)));
        assertTrue(ok, "withdraw failed");

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(this));
        assertGe(balanceAfter, amount - 1);
    }
}
