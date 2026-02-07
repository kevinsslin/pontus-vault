// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ITrancheToken} from "../../src/interfaces/ITrancheToken.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {BaseTest} from "../BaseTest.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract TrancheTokenTest is BaseTest {
    TrancheToken internal token;

    address internal controllerAddr;
    address internal holder;
    address internal spender;

    function setUp() public override {
        BaseTest.setUp();
        controllerAddr = makeAddr("controller");
        holder = makeAddr("holder");
        spender = makeAddr("spender");

        token = new TrancheToken();
        token.initialize(
            TestDefaults.SENIOR_TOKEN_NAME,
            TestDefaults.SENIOR_TOKEN_SYMBOL,
            TestConstants.USDC_DECIMALS,
            controllerAddr
        );
    }

    function test_initialize_revertsWhenControllerIsZero() public {
        TrancheToken another = new TrancheToken();
        vm.expectRevert(ITrancheToken.ZeroAddress.selector);
        another.initialize(
            TestDefaults.SENIOR_TOKEN_NAME,
            TestDefaults.SENIOR_TOKEN_SYMBOL,
            TestConstants.USDC_DECIMALS,
            TestConstants.ZERO_ADDRESS
        );
    }

    function test_initialize_revertsOnSecondCall() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize(
            TestDefaults.TOKEN_REINIT_NAME,
            TestDefaults.TOKEN_REINIT_SYMBOL,
            TestConstants.USDC_DECIMALS,
            controllerAddr
        );
    }

    function test_mint_revertsForNonController() public {
        vm.prank(holder);
        vm.expectRevert(ITrancheToken.NotController.selector);
        token.mint(holder, TestConstants.ONE_UNIT);
    }

    function test_mintTransferAndTransferFrom() public {
        vm.prank(controllerAddr);
        token.mint(holder, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(holder);
        token.transfer(spender, TestConstants.TOKEN_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(holder), TestConstants.TOKEN_MINT_AMOUNT - TestConstants.TOKEN_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(spender), TestConstants.TOKEN_TRANSFER_AMOUNT);

        vm.prank(holder);
        token.approve(spender, TestConstants.TOKEN_APPROVE_AMOUNT);

        vm.prank(spender);
        token.transferFrom(holder, spender, TestConstants.TOKEN_APPROVE_AMOUNT);
        assertEq(
            token.balanceOf(holder),
            TestConstants.TOKEN_MINT_AMOUNT - TestConstants.TOKEN_TRANSFER_AMOUNT - TestConstants.TOKEN_APPROVE_AMOUNT
        );
        assertEq(token.balanceOf(spender), TestConstants.TOKEN_TRANSFER_AMOUNT + TestConstants.TOKEN_APPROVE_AMOUNT);
    }

    function test_burnFrom_revertsWithoutControllerAllowance() public {
        vm.prank(controllerAddr);
        token.mint(holder, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(controllerAddr);
        vm.expectRevert(ITrancheToken.InsufficientAllowance.selector);
        token.burnFrom(holder, TestConstants.ONE_UNIT);
    }

    function test_burnFrom_revertsForNonController() public {
        vm.prank(controllerAddr);
        token.mint(holder, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(holder);
        token.approve(spender, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(spender);
        vm.expectRevert(ITrancheToken.NotController.selector);
        token.burnFrom(holder, TestConstants.ONE_UNIT);
    }

    function test_burnFrom_success() public {
        vm.prank(controllerAddr);
        token.mint(holder, TestConstants.TOKEN_MINT_AMOUNT);

        vm.prank(holder);
        token.approve(controllerAddr, TestConstants.TOKEN_BURN_APPROVAL);

        vm.prank(controllerAddr);
        token.burnFrom(holder, TestConstants.TOKEN_BURN_AMOUNT);

        assertEq(token.totalSupply(), TestConstants.TOKEN_POST_BURN_SUPPLY);
        assertEq(token.balanceOf(holder), TestConstants.TOKEN_POST_BURN_SUPPLY);
        assertEq(token.allowance(holder, controllerAddr), TestConstants.TOKEN_POST_BURN_ALLOWANCE);
    }
}
