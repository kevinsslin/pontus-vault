// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOpenFiPool} from "../../src/interfaces/IOpenFiPool.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract OpenFiForkTest is Test {
    function _runRoundtrip(address asset, uint256 amount) internal {
        deal(asset, address(this), amount);
        IERC20(asset).approve(TestConstants.OPENFI_POOL, amount);

        (bool ok,) = TestConstants.OPENFI_POOL.call(OpenFiCallBuilder.supplyCalldata(asset, amount, address(this)));
        assertTrue(ok, "supply failed");

        (ok,) = TestConstants.OPENFI_POOL.call(OpenFiCallBuilder.withdrawCalldata(asset, amount, address(this)));
        assertTrue(ok, "withdraw failed");

        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        assertGe(balanceAfter, amount - TestConstants.FORK_BALANCE_DUST_TOLERANCE);
    }

    function testOpenFiSupplyWithdrawRoundtrip() external {
        string memory rpc = vm.envOr("PHAROS_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log(TestDefaults.LOG_SKIP_FORK);
            return;
        }

        vm.selectFork(vm.createFork(rpc));

        assertEq(OpenFiCallBuilder.supplySelector(), IOpenFiPool.supply.selector);
        assertEq(OpenFiCallBuilder.withdrawSelector(), IOpenFiPool.withdraw.selector);

        _runRoundtrip(TestConstants.PHAROS_USDC, TestConstants.OPENFI_FORK_ROUNDTRIP);
        _runRoundtrip(TestConstants.PHAROS_USDT, TestConstants.OPENFI_FORK_ROUNDTRIP);
    }
}
