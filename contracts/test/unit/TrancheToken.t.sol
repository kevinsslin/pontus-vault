// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract TrancheTokenTest is Test {
    TrancheToken internal token;

    address internal controller;
    address internal alice;
    address internal bob;

    function setUp() public {
        controller = makeAddr("controller");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new TrancheToken();
        token.initialize(
            TestDefaults.SENIOR_TOKEN_NAME, TestDefaults.SENIOR_TOKEN_SYMBOL, TestConstants.USDC_DECIMALS, controller
        );
    }

    function test_initialize_revertsWhenControllerIsZero() public {
        TrancheToken another = new TrancheToken();
        vm.expectRevert(TrancheToken.ZeroAddress.selector);
        another.initialize(
            TestDefaults.SENIOR_TOKEN_NAME, TestDefaults.SENIOR_TOKEN_SYMBOL, TestConstants.USDC_DECIMALS, address(0)
        );
    }

    function test_initialize_revertsOnSecondCall() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("Again", "AGAIN", 6, controller);
    }

    function test_mint_revertsForNonController() public {
        vm.prank(alice);
        vm.expectRevert(TrancheToken.NotController.selector);
        token.mint(alice, TestConstants.ONE_UNIT);
    }

    function test_mintTransferAndTransferFrom() public {
        vm.prank(controller);
        token.mint(alice, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(alice);
        token.transfer(bob, TestConstants.TOKEN_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(alice), TestConstants.TOKEN_MINT_AMOUNT - TestConstants.TOKEN_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(bob), TestConstants.TOKEN_TRANSFER_AMOUNT);

        vm.prank(alice);
        token.approve(bob, TestConstants.TOKEN_APPROVE_AMOUNT);

        vm.prank(bob);
        token.transferFrom(alice, bob, TestConstants.TOKEN_APPROVE_AMOUNT);
        assertEq(
            token.balanceOf(alice),
            TestConstants.TOKEN_MINT_AMOUNT - TestConstants.TOKEN_TRANSFER_AMOUNT - TestConstants.TOKEN_APPROVE_AMOUNT
        );
        assertEq(token.balanceOf(bob), TestConstants.TOKEN_TRANSFER_AMOUNT + TestConstants.TOKEN_APPROVE_AMOUNT);
    }

    function test_burnFrom_revertsWithoutControllerAllowance() public {
        vm.prank(controller);
        token.mint(alice, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(controller);
        vm.expectRevert(TrancheToken.InsufficientAllowance.selector);
        token.burnFrom(alice, TestConstants.ONE_UNIT);
    }

    function test_burnFrom_revertsForNonController() public {
        vm.prank(controller);
        token.mint(alice, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(alice);
        token.approve(bob, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(bob);
        vm.expectRevert(TrancheToken.NotController.selector);
        token.burnFrom(alice, TestConstants.ONE_UNIT);
    }

    function test_burnFrom_success() public {
        vm.prank(controller);
        token.mint(alice, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(alice);
        token.approve(controller, TestConstants.TOKEN_BURN_APPROVAL);

        vm.prank(controller);
        token.burnFrom(alice, TestConstants.TOKEN_BURN_AMOUNT);

        assertEq(token.totalSupply(), TestConstants.TOKEN_POST_BURN_SUPPLY);
        assertEq(token.balanceOf(alice), TestConstants.TOKEN_POST_BURN_SUPPLY);
        assertEq(token.allowance(alice, controller), TestConstants.TOKEN_POST_BURN_ALLOWANCE);
    }
}
