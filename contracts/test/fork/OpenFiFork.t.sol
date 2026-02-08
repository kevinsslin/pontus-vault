// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOpenFiPool} from "../../src/interfaces/openfi/IOpenFiPool.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseForkTest} from "./BaseForkTest.sol";

contract OpenFiForkTest is BaseForkTest {
    function _runRoundtrip(address _asset, uint256 _amount) internal {
        deal(_asset, address(this), _amount);
        IERC20(_asset).approve(TestConstants.PHAROS_ATLANTIC_OPENFI_POOL, _amount);

        (bool ok,) = TestConstants.PHAROS_ATLANTIC_OPENFI_POOL
            .call(OpenFiCallBuilder.supplyCalldata(_asset, _amount, address(this)));
        assertTrue(ok, "supply failed");

        (ok,) = TestConstants.PHAROS_ATLANTIC_OPENFI_POOL
            .call(OpenFiCallBuilder.withdrawCalldata(_asset, _amount, address(this)));
        assertTrue(ok, "withdraw failed");

        uint256 balanceAfter = IERC20(_asset).balanceOf(address(this));
        assertGe(balanceAfter, _amount - TestDefaults.FORK_BALANCE_DUST_TOLERANCE);
    }

    function test_open_fi_supply_withdraw_roundtrip() external {
        _createFork();

        assertEq(OpenFiCallBuilder.supplySelector(), IOpenFiPool.supply.selector);
        assertEq(OpenFiCallBuilder.withdrawSelector(), IOpenFiPool.withdraw.selector);

        _runRoundtrip(TestConstants.PHAROS_ATLANTIC_USDC, TestDefaults.OPENFI_FORK_ROUNDTRIP);
        _runRoundtrip(TestConstants.PHAROS_ATLANTIC_USDT, TestDefaults.OPENFI_FORK_ROUNDTRIP);
    }
}
