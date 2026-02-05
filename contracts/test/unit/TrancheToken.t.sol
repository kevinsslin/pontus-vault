// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {TrancheToken} from "../../src/tranche/TrancheToken.sol";

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
        token.initialize("Pontus Vault Senior USDC S1", "pvS-USDC", 6, controller);
    }

    function test_initialize_revertsWhenControllerIsZero() public {
        TrancheToken another = new TrancheToken();
        vm.expectRevert(TrancheToken.ZeroAddress.selector);
        another.initialize("Pontus Vault Senior USDC S1", "pvS-USDC", 6, address(0));
    }

    function test_initialize_revertsOnSecondCall() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("Again", "AGAIN", 6, controller);
    }

    function test_mint_revertsForNonController() public {
        vm.prank(alice);
        vm.expectRevert(TrancheToken.NotController.selector);
        token.mint(alice, 1e6);
    }

    function test_mintTransferAndTransferFrom() public {
        vm.prank(controller);
        token.mint(alice, 10e6);

        vm.prank(alice);
        token.transfer(bob, 3e6);
        assertEq(token.balanceOf(alice), 7e6);
        assertEq(token.balanceOf(bob), 3e6);

        vm.prank(alice);
        token.approve(bob, 2e6);

        vm.prank(bob);
        token.transferFrom(alice, bob, 2e6);
        assertEq(token.balanceOf(alice), 5e6);
        assertEq(token.balanceOf(bob), 5e6);
    }

    function test_burnFrom_revertsWithoutControllerAllowance() public {
        vm.prank(controller);
        token.mint(alice, 10e6);

        vm.prank(controller);
        vm.expectRevert(TrancheToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 1e6);
    }

    function test_burnFrom_revertsForNonController() public {
        vm.prank(controller);
        token.mint(alice, 10e6);

        vm.prank(alice);
        token.approve(bob, 10e6);

        vm.prank(bob);
        vm.expectRevert(TrancheToken.NotController.selector);
        token.burnFrom(alice, 1e6);
    }

    function test_burnFrom_success() public {
        vm.prank(controller);
        token.mint(alice, 10e6);

        vm.prank(alice);
        token.approve(controller, 6e6);

        vm.prank(controller);
        token.burnFrom(alice, 4e6);

        assertEq(token.totalSupply(), 6e6);
        assertEq(token.balanceOf(alice), 6e6);
        assertEq(token.allowance(alice, controller), 2e6);
    }
}
