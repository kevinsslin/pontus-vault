// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "../BaseTest.sol";
import {TestTeller} from "../mocks/TestTeller.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";

contract MockRateModel {
    uint256 internal _rate;

    function setRatePerSecondWad(uint256 newRate) external {
        _rate = newRate;
    }

    function getRatePerSecondWad() external view returns (uint256) {
        return _rate;
    }
}

contract TrancheControllerTest is BaseTest {
    TestTeller internal teller;
    MockRateModel internal rateModel;

    function setUp() public {
        _initActors();
        _initRules();
        _deployCore("USDC", "USDC", 6);
        teller = new TestTeller(IERC20(address(asset)), testAccountant);
        rateModel = new MockRateModel();
        _initController(address(teller), address(teller), address(0), address(testAccountant));
        _seedBalances(1_000_000e6);
    }

    // preview + valuation rules
    function test_previewRedeemSenior_juniorAbsorbsLosses() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);

        testAccountant.setRate(IERC20(address(asset)), 1.1e18);

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

        testAccountant.setRate(IERC20(address(asset)), 0.7e18);

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
        testAccountant.setRate(IERC20(address(asset)), 0.7e18);

        vm.startPrank(bob);
        asset.approve(address(controller), 10e6);
        vm.expectRevert(TrancheController.UnderwaterJunior.selector);
        controller.depositJunior(10e6, bob);
        vm.stopPrank();
    }

    function test_zeroAmount_revertsAcrossMutatingActions() public {
        vm.startPrank(alice);
        asset.approve(address(controller), 1e6);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.depositSenior(0, alice);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.depositJunior(0, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        seniorToken.approve(address(controller), 1e6);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.redeemSenior(0, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        juniorToken.approve(address(controller), 1e6);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.redeemJunior(0, alice);
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
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, controller.GUARDIAN_ROLE()
            )
        );
        controller.pause();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, bob, controller.OPERATOR_ROLE()
            )
        );
        controller.setSeniorRatePerSecondWad(1);
        vm.stopPrank();
    }

    function test_operatorConfig_updatesAndGuards() public {
        vm.prank(operator);
        controller.setMaxSeniorRatioBps(9_000);
        assertEq(controller.maxSeniorRatioBps(), 9_000);

        vm.prank(operator);
        vm.expectRevert(TrancheController.InvalidBps.selector);
        controller.setMaxSeniorRatioBps(10_001);

        vm.prank(operator);
        vm.expectRevert(TrancheController.ZeroAddress.selector);
        controller.setTeller(address(0));

        vm.prank(operator);
        controller.setTeller(address(teller));
        assertEq(address(controller.teller()), address(teller));
    }

    function test_accrue_usesRateModelWhenConfigured() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);
        assertEq(controller.seniorDebt(), 800e6);

        rateModel.setRatePerSecondWad(1e14);
        vm.prank(operator);
        controller.setRateModel(address(rateModel));

        vm.warp(block.timestamp + 3_600);
        controller.accrue();

        assertGt(controller.seniorDebt(), 800e6);
    }

    function test_redeemSenior_decreasesDebtAndReturnsAssets() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);

        uint256 sharesIn = seniorToken.balanceOf(alice) / 2;
        uint256 expectedAssets = controller.previewRedeemSenior(sharesIn);
        uint256 debtBefore = controller.seniorDebt();
        uint256 balBefore = asset.balanceOf(alice);

        vm.startPrank(alice);
        seniorToken.approve(address(controller), sharesIn);
        uint256 assetsOut = controller.redeemSenior(sharesIn, alice);
        vm.stopPrank();

        assertEq(assetsOut, expectedAssets);
        assertEq(asset.balanceOf(alice), balBefore + assetsOut);
        assertEq(controller.seniorDebt(), debtBefore - assetsOut);
    }

    function test_redeemJunior_returnsAssetsWhenHealthy() public {
        _depositJunior(bob, 200e6);
        _depositSenior(alice, 800e6);
        testAccountant.setRate(IERC20(address(asset)), 1.1e18);

        uint256 sharesIn = juniorToken.balanceOf(bob) / 2;
        uint256 expectedAssets = controller.previewRedeemJunior(sharesIn);
        uint256 balBefore = asset.balanceOf(bob);

        vm.startPrank(bob);
        juniorToken.approve(address(controller), sharesIn);
        uint256 assetsOut = controller.redeemJunior(sharesIn, bob);
        vm.stopPrank();

        assertEq(assetsOut, expectedAssets);
        assertEq(asset.balanceOf(bob), balBefore + assetsOut);
    }

    function testFuzz_seniorPrice_noJumpOnSeniorDeposit(uint96 juniorSeed, uint96 seniorSeed, uint96 additionalSeed)
        public
    {
        uint256 juniorAssets = bound(uint256(juniorSeed), 100e6, 300_000e6);
        uint256 maxSenior = juniorAssets * 4;
        if (maxSenior > 800_000e6) maxSenior = 800_000e6;
        uint256 seniorAssets = bound(uint256(seniorSeed), 100e6, maxSenior);
        _depositJunior(bob, juniorAssets);
        _depositSenior(alice, seniorAssets);

        uint256 v0 = controller.previewV();
        uint256 d0 = controller.seniorDebt();
        uint256 s0 = seniorToken.totalSupply();
        if (s0 == 0) return;

        uint256 maxAdditional = 0;
        if (4 * v0 > 5 * d0) {
            maxAdditional = 4 * v0 - 5 * d0;
        }
        if (maxAdditional == 0) return;

        uint256 remaining = 1_000_000e6 - seniorAssets;
        if (remaining == 0) return;
        uint256 limit = maxAdditional < remaining ? maxAdditional : remaining;
        uint256 additional = bound(uint256(additionalSeed), 1e6, limit);

        uint256 priceBefore = (d0 * 1e18) / s0;
        _depositSenior(alice, additional);

        uint256 v1 = controller.previewV();
        uint256 d1 = controller.seniorDebt();
        uint256 s1 = seniorToken.totalSupply();
        uint256 seniorValue1 = v1 < d1 ? v1 : d1;
        uint256 priceAfter = (seniorValue1 * 1e18) / s1;

        assertApproxEqAbs(priceBefore, priceAfter, 2);
    }

    function testFuzz_juniorPrice_noJumpOnJuniorDeposit(uint96 juniorSeed, uint96 seniorSeed, uint96 additionalSeed)
        public
    {
        uint256 juniorAssets = bound(uint256(juniorSeed), 100e6, 500_000e6);
        uint256 maxSenior = juniorAssets * 4;
        if (maxSenior > 800_000e6) maxSenior = 800_000e6;
        uint256 seniorAssets = bound(uint256(seniorSeed), 100e6, maxSenior);
        _depositJunior(bob, juniorAssets);
        _depositSenior(alice, seniorAssets);

        uint256 v0 = controller.previewV();
        uint256 d0 = controller.seniorDebt();
        if (v0 <= d0) return;

        uint256 j0 = juniorToken.totalSupply();
        if (j0 == 0) return;

        uint256 juniorValue0 = v0 - d0;
        uint256 priceBefore = (juniorValue0 * 1e18) / j0;

        uint256 remaining = 1_000_000e6 - juniorAssets;
        if (remaining == 0) return;
        uint256 additional = bound(uint256(additionalSeed), 1e6, remaining);

        _depositJunior(bob, additional);

        uint256 v1 = controller.previewV();
        uint256 d1 = controller.seniorDebt();
        uint256 j1 = juniorToken.totalSupply();
        uint256 juniorValue1 = v1 > d1 ? (v1 - d1) : 0;
        uint256 priceAfter = (juniorValue1 * 1e18) / j1;

        assertApproxEqAbs(priceBefore, priceAfter, 2);
    }

    // deposit helpers come from BaseTest
}
