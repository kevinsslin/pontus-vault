// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOpenFiPool} from "../../src/interfaces/IOpenFiPool.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";

contract OpenFiForkTest is Test {
    address internal constant POOL = 0xEC86f142E7334d99EEEF2c43298413299D919B30;
    address internal constant USDC = 0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8;
    address internal constant USDT = 0xE7E84B8B4f39C507499c40B4ac199B050e2882d5;

    function _runRoundtrip(address asset, uint256 amount) internal {
        deal(asset, address(this), amount);
        IERC20(asset).approve(POOL, amount);

        (bool ok,) = POOL.call(OpenFiCallBuilder.supplyCalldata(asset, amount, address(this)));
        assertTrue(ok, "supply failed");

        (ok,) = POOL.call(OpenFiCallBuilder.withdrawCalldata(asset, amount, address(this)));
        assertTrue(ok, "withdraw failed");

        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        assertGe(balanceAfter, amount - 1);
    }

    function testOpenFiSupplyWithdrawRoundtrip() external {
        string memory rpc = vm.envOr("PHAROS_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log("PHAROS_RPC_URL not set; skipping OpenFi fork test.");
            return;
        }

        vm.selectFork(vm.createFork(rpc));

        assertEq(OpenFiCallBuilder.supplySelector(), IOpenFiPool.supply.selector);
        assertEq(OpenFiCallBuilder.withdrawSelector(), IOpenFiPool.withdraw.selector);

        _runRoundtrip(USDC, 1_000e6);
        _runRoundtrip(USDT, 1_000e6);
    }
}
