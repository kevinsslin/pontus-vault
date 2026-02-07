// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {TestConstants} from "../utils/Constants.sol";

import {IntegrationTest} from "./IntegrationTest.sol";

contract TrancheIntegrationTest is IntegrationTest {
    function setUp() public override {
        IntegrationTest.setUp();
        _wireControllerToBoringVault(TestConstants.ZERO_ADDRESS);
        _seedBalances(TestConstants.DEFAULT_INITIAL_BALANCE);
    }

    function test_deposit_redeem_roundtrip_via_boring_vault_stack() public {
        _depositJunior(alice, TestConstants.DEFAULT_JUNIOR_DEPOSIT);
        _depositSenior(bob, TestConstants.DEFAULT_SENIOR_DEPOSIT);

        assertEq(boringVault.balanceOf(address(controller)), TestConstants.DEFAULT_TOTAL_BORING_SHARES);

        uint256 seniorShares = seniorToken.balanceOf(bob);
        uint256 bobBalanceBefore = asset.balanceOf(bob);

        vm.startPrank(bob);
        seniorToken.approve(address(controller), seniorShares);
        controller.redeemSenior(seniorShares, bob);
        vm.stopPrank();

        assertEq(asset.balanceOf(bob), bobBalanceBefore + TestConstants.DEFAULT_SENIOR_DEPOSIT);
        assertEq(boringVault.balanceOf(address(controller)), TestConstants.DEFAULT_JUNIOR_REMAINING_SHARES);
    }

    // deposit helpers come from BaseTest
}
