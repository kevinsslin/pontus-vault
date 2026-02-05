// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {AccessControl} from "../../src/libraries/AccessControl.sol";
import {Pausable} from "../../src/libraries/Pausable.sol";
import {JuniorToken} from "../../src/tranche/JuniorToken.sol";
import {SeniorToken} from "../../src/tranche/SeniorToken.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {IERC20Minimal} from "../../src/interfaces/IERC20Minimal.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockTeller} from "../mocks/MockTeller.sol";

contract TrancheControllerTest is Test {
    MockERC20 internal asset;
    MockTeller internal teller;
    TrancheController internal controller;
    SeniorToken internal seniorToken;
    JuniorToken internal juniorToken;

    address internal operator;
    address internal guardian;
    address internal alice;
    address internal bob;

    function setUp() public {
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        asset = new MockERC20("USDC", "USDC", 6);
        teller = new MockTeller(IERC20Minimal(address(asset)));

        controller = new TrancheController();
        seniorToken = new SeniorToken();
        juniorToken = new JuniorToken();

        seniorToken.initialize("Pontus Vault Senior USDC S1", "pvS-USDC", 6, address(controller));
        juniorToken.initialize("Pontus Vault Junior USDC S1", "pvJ-USDC", 6, address(controller));

        controller.initialize(
            address(asset),
            address(teller),
            address(teller),
            operator,
            guardian,
            address(seniorToken),
            address(juniorToken),
            0,
            address(0),
            8000
        );

        asset.mint(alice, 1_000_000e6);
        asset.mint(bob, 1_000_000e6);
    }

    function testWaterfallSeniorCappedJuniorResidual() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);

        teller.setSharePriceWad(1.1e18);

        uint256 seniorShares = seniorToken.balanceOf(alice);
        uint256 juniorShares = juniorToken.balanceOf(bob);

        uint256 seniorAssets = controller.previewRedeemSenior(seniorShares);
        uint256 juniorAssets = controller.previewRedeemJunior(juniorShares);

        assertEq(seniorAssets, 800e6);
        assertEq(juniorAssets, 300e6);
    }

    function testLossAbsorptionJuniorWiped() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);

        teller.setSharePriceWad(0.7e18);

        uint256 seniorShares = seniorToken.balanceOf(alice);
        uint256 juniorShares = juniorToken.balanceOf(bob);

        uint256 seniorAssets = controller.previewRedeemSenior(seniorShares);
        uint256 juniorAssets = controller.previewRedeemJunior(juniorShares);

        assertEq(juniorAssets, 0);
        assertEq(seniorAssets, 700e6);
    }

    function testMaxSeniorRatioCap() public {
        _depositJunior(alice, 200e6);
        _depositSenior(bob, 800e6);

        vm.startPrank(bob);
        asset.approve(address(controller), 1e6);
        vm.expectRevert(TrancheController.MaxSeniorRatioExceeded.selector);
        controller.depositSenior(1e6, bob);
        vm.stopPrank();
    }

    function testUnderwaterJuniorDepositReverts() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);
        teller.setSharePriceWad(0.7e18);

        vm.startPrank(bob);
        asset.approve(address(controller), 10e6);
        vm.expectRevert(TrancheController.UnderwaterJunior.selector);
        controller.depositJunior(10e6, bob);
        vm.stopPrank();
    }

    function testPauseBlocksDepositsAndRedeems() public {
        _depositJunior(bob, 50e6);
        _depositSenior(alice, 100e6);

        vm.prank(guardian);
        controller.pause();

        vm.startPrank(alice);
        asset.approve(address(controller), 10e6);
        vm.expectRevert(Pausable.PausedError.selector);
        controller.depositSenior(10e6, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        seniorToken.approve(address(controller), 50e6);
        vm.expectRevert(Pausable.PausedError.selector);
        controller.redeemSenior(50e6, alice);
        vm.stopPrank();

        vm.prank(guardian);
        controller.unpause();
        _depositSenior(alice, 10e6);
    }

    function testRoleChecks() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccessControl.MissingRole.selector, alice, controller.GUARDIAN_ROLE()));
        controller.pause();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(AccessControl.MissingRole.selector, bob, controller.OPERATOR_ROLE()));
        controller.setSeniorRatePerSecondWad(1);
        vm.stopPrank();
    }

    function _depositSenior(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(controller), amount);
        controller.depositSenior(amount, user);
        vm.stopPrank();
    }

    function _depositJunior(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(controller), amount);
        controller.depositJunior(amount, user);
        vm.stopPrank();
    }
}
