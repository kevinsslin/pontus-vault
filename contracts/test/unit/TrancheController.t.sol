// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "../BaseTest.sol";
import {MockTeller} from "../mocks/MockTeller.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";

contract TrancheControllerTest is BaseTest {
    MockTeller internal teller;

    function setUp() public {
        _initActors();
        _initRules();
        _deployCore("USDC", "USDC", 6);
        teller = new MockTeller(IERC20(address(asset)));
        _initController(address(teller), address(teller), address(0));
        _seedBalances(1_000_000e6);
    }

    // preview + valuation rules
    function test_previewRedeemSenior_juniorAbsorbsLosses() public {
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

    function test_previewRedeemJunior_isZeroWhenUnderwater() public {
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

    // depositSenior rules
    function test_depositSenior_revertsWhenMaxSeniorRatioExceeded() public {
        _depositJunior(alice, 200e6);
        _depositSenior(bob, 800e6);

        vm.startPrank(bob);
        asset.approve(address(controller), 1e6);
        vm.expectRevert(TrancheController.MaxSeniorRatioExceeded.selector);
        controller.depositSenior(1e6, bob);
        vm.stopPrank();
    }

    // depositJunior rules
    function test_depositJunior_revertsWhenUnderwater() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);
        teller.setSharePriceWad(0.7e18);

        vm.startPrank(bob);
        asset.approve(address(controller), 10e6);
        vm.expectRevert(TrancheController.UnderwaterJunior.selector);
        controller.depositJunior(10e6, bob);
        vm.stopPrank();
    }

    // pause rules
    function test_pause_blocksDepositsAndRedeems() public {
        _depositJunior(bob, 50e6);
        _depositSenior(alice, 100e6);

        vm.prank(guardian);
        controller.pause();

        vm.startPrank(alice);
        asset.approve(address(controller), 10e6);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.depositSenior(10e6, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        seniorToken.approve(address(controller), 50e6);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.redeemSenior(50e6, alice);
        vm.stopPrank();

        vm.prank(guardian);
        controller.unpause();
        _depositSenior(alice, 10e6);
    }

    // access control rules
    function test_roleChecks() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, controller.GUARDIAN_ROLE())
        );
        controller.pause();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, controller.OPERATOR_ROLE())
        );
        controller.setSeniorRatePerSecondWad(1);
        vm.stopPrank();
    }

    // deposit helpers come from BaseTest
}
