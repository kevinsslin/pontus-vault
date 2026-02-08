// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ITrancheController} from "../../src/interfaces/tranche/ITrancheController.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {IntegrationTest} from "./IntegrationTest.sol";

contract TrancheIntegrationTest is IntegrationTest {
    function setUp() public override {
        IntegrationTest.setUp();
        _wireControllerToBoringVault(TestConstants.ZERO_ADDRESS);
        _seedBalances(TestDefaults.DEFAULT_INITIAL_BALANCE);
    }

    function test_deposit_redeem_roundtrip_via_boring_vault_stack() public {
        _depositJunior(alice, TestDefaults.DEFAULT_JUNIOR_DEPOSIT);
        _depositSenior(bob, TestDefaults.DEFAULT_SENIOR_DEPOSIT);

        assertEq(boringVault.balanceOf(address(controller)), TestDefaults.DEFAULT_TOTAL_BORING_SHARES);

        uint256 seniorShares = seniorToken.balanceOf(bob);
        uint256 bobBalanceBefore = asset.balanceOf(bob);

        vm.startPrank(bob);
        seniorToken.approve(address(controller), seniorShares);
        controller.redeemSenior(seniorShares, bob);
        vm.stopPrank();

        assertEq(asset.balanceOf(bob), bobBalanceBefore + TestDefaults.DEFAULT_SENIOR_DEPOSIT);
        assertEq(boringVault.balanceOf(address(controller)), TestDefaults.DEFAULT_JUNIOR_REMAINING_SHARES);
    }

    function test_deposits_revert_when_exchange_rate_is_stale() public {
        vm.prank(operator);
        controller.setMaxRateAge(1);

        vm.warp(block.timestamp + 2);

        vm.startPrank(alice);
        asset.approve(address(controller), TestDefaults.SMALL_DEPOSIT);
        vm.expectRevert(ITrancheController.StaleExchangeRate.selector);
        controller.depositJunior(TestDefaults.SMALL_DEPOSIT, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(controller), TestDefaults.SMALL_DEPOSIT);
        vm.expectRevert(ITrancheController.StaleExchangeRate.selector);
        controller.depositSenior(TestDefaults.SMALL_DEPOSIT, bob);
        vm.stopPrank();
    }

    // deposit helpers come from BaseTest
}
