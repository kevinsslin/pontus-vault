// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "../BaseTest.sol";
import {MockTeller} from "../mocks/MockTeller.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TestConstants} from "../utils/Constants.sol";

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
    MockTeller internal teller;
    MockRateModel internal rateModel;

    function setUp() public override {
        super.setUp();
        teller = new MockTeller(IERC20(address(asset)), mockAccountant);
        rateModel = new MockRateModel();
        _initController(address(teller), address(teller), TestConstants.ZERO_ADDRESS, address(mockAccountant));
        _seedBalances(TestConstants.DEFAULT_INITIAL_BALANCE);
    }

    function _seedHealthyPool(address seniorUser, address juniorUser) internal {
        _depositJunior(juniorUser, TestConstants.DEFAULT_JUNIOR_DEPOSIT);
        _depositSenior(seniorUser, TestConstants.DEFAULT_SENIOR_DEPOSIT);
    }

    function _seedUnderwaterPool(address seniorUser, address juniorUser) internal {
        _seedHealthyPool(seniorUser, juniorUser);
        mockAccountant.setRate(IERC20(address(asset)), TestConstants.ACCOUNTANT_BEAR_RATE);
    }

    // preview + valuation rules
    function test_previewRedeemSenior_juniorAbsorbsLosses() public {
        _seedHealthyPool(alice, bob);

        mockAccountant.setRate(IERC20(address(asset)), TestConstants.ACCOUNTANT_BULL_RATE);

        uint256 seniorShares = seniorToken.balanceOf(alice);
        uint256 juniorShares = juniorToken.balanceOf(bob);

        uint256 seniorAssets = controller.previewRedeemSenior(seniorShares);
        uint256 juniorAssets = controller.previewRedeemJunior(juniorShares);

        assertEq(seniorAssets, TestConstants.DEFAULT_SENIOR_DEPOSIT);
        assertEq(
            juniorAssets,
            TestConstants.DEFAULT_JUNIOR_DEPOSIT
                + (TestConstants.DEFAULT_SENIOR_DEPOSIT / TestConstants.SENIOR_UPSIDE_DIVISOR)
        );
    }

    function test_previewRedeemJunior_isZeroWhenUnderwater() public {
        _seedUnderwaterPool(alice, bob);

        uint256 seniorShares = seniorToken.balanceOf(alice);
        uint256 juniorShares = juniorToken.balanceOf(bob);

        uint256 seniorAssets = controller.previewRedeemSenior(seniorShares);
        uint256 juniorAssets = controller.previewRedeemJunior(juniorShares);

        assertEq(juniorAssets, 0);
        assertEq(seniorAssets, TestConstants.UNDERWATER_SENIOR_ASSETS);
    }

    // depositSenior rules
    function test_depositSenior_revertsWhenMaxSeniorRatioExceeded() public {
        _seedHealthyPool(bob, alice);

        vm.startPrank(bob);
        asset.approve(address(controller), TestConstants.ONE_UNIT);
        vm.expectRevert(TrancheController.MaxSeniorRatioExceeded.selector);
        controller.depositSenior(TestConstants.ONE_UNIT, bob);
        vm.stopPrank();
    }

    // depositJunior rules
    function test_depositJunior_revertsWhenUnderwater() public {
        _seedUnderwaterPool(alice, bob);

        vm.startPrank(bob);
        asset.approve(address(controller), TestConstants.SMALL_DEPOSIT);
        vm.expectRevert(TrancheController.UnderwaterJunior.selector);
        controller.depositJunior(TestConstants.SMALL_DEPOSIT, bob);
        vm.stopPrank();
    }

    function test_zeroAmount_revertsAcrossMutatingActions() public {
        vm.startPrank(alice);
        asset.approve(address(controller), TestConstants.ONE_UNIT);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.depositSenior(0, alice);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.depositJunior(0, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        seniorToken.approve(address(controller), TestConstants.ONE_UNIT);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.redeemSenior(0, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        juniorToken.approve(address(controller), TestConstants.ONE_UNIT);
        vm.expectRevert(TrancheController.ZeroAmount.selector);
        controller.redeemJunior(0, alice);
        vm.stopPrank();
    }

    // pause rules
    function test_pause_blocksDepositsAndRedeems() public {
        _depositJunior(bob, TestConstants.SMALL_JUNIOR_DEPOSIT);
        _depositSenior(alice, TestConstants.SMALL_DEPOSIT * TestConstants.SMALL_SENIOR_MULTIPLIER);

        vm.prank(guardian);
        controller.pause();

        vm.startPrank(alice);
        asset.approve(address(controller), TestConstants.SMALL_DEPOSIT);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.depositSenior(TestConstants.SMALL_DEPOSIT, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        seniorToken.approve(address(controller), TestConstants.SMALL_SHARES);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.redeemSenior(TestConstants.SMALL_SHARES, alice);
        vm.stopPrank();

        vm.prank(guardian);
        controller.unpause();
        _depositSenior(alice, TestConstants.SMALL_DEPOSIT);
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
        controller.setSeniorRatePerSecondWad(TestConstants.ROLE_TEST_RATE);
        vm.stopPrank();
    }

    function test_operatorConfig_updatesAndGuards() public {
        vm.prank(operator);
        controller.setMaxSeniorRatioBps(TestConstants.UPDATED_MAX_SENIOR_RATIO_BPS);
        assertEq(controller.maxSeniorRatioBps(), TestConstants.UPDATED_MAX_SENIOR_RATIO_BPS);

        vm.prank(operator);
        vm.expectRevert(TrancheController.InvalidBps.selector);
        controller.setMaxSeniorRatioBps(TestConstants.INVALID_BPS);

        vm.prank(operator);
        vm.expectRevert(TrancheController.ZeroAddress.selector);
        controller.setTeller(TestConstants.ZERO_ADDRESS);

        vm.prank(operator);
        controller.setTeller(address(teller));
        assertEq(address(controller.teller()), address(teller));
    }

    function test_accrue_usesRateModelWhenConfigured() public {
        _seedHealthyPool(alice, bob);
        assertEq(controller.seniorDebt(), TestConstants.DEFAULT_SENIOR_DEPOSIT);

        rateModel.setRatePerSecondWad(TestConstants.ACCRUAL_TEST_RATE);
        vm.prank(operator);
        controller.setRateModel(address(rateModel));

        vm.warp(block.timestamp + TestConstants.ACCRUAL_WARP_SECONDS);
        controller.accrue();

        assertGt(controller.seniorDebt(), TestConstants.DEFAULT_SENIOR_DEPOSIT);
    }

    function test_redeemSenior_decreasesDebtAndReturnsAssets() public {
        _seedHealthyPool(alice, bob);

        uint256 sharesIn = seniorToken.balanceOf(alice) / TestConstants.HALF_POSITION;
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
        _seedHealthyPool(alice, bob);
        mockAccountant.setRate(IERC20(address(asset)), TestConstants.ACCOUNTANT_BULL_RATE);

        uint256 sharesIn = juniorToken.balanceOf(bob) / TestConstants.HALF_POSITION;
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
        uint256 juniorAssets =
            bound(uint256(juniorSeed), TestConstants.FUZZ_MIN_ASSETS, TestConstants.FUZZ_MAX_JUNIOR_A);
        uint256 maxSenior = juniorAssets * TestConstants.SENIOR_CAP_NUMERATOR;
        if (maxSenior > TestConstants.FUZZ_MAX_SENIOR) maxSenior = TestConstants.FUZZ_MAX_SENIOR;
        uint256 seniorAssets = bound(uint256(seniorSeed), TestConstants.FUZZ_MIN_ASSETS, maxSenior);
        _depositJunior(bob, juniorAssets);
        _depositSenior(alice, seniorAssets);

        uint256 v0 = controller.previewV();
        uint256 d0 = controller.seniorDebt();
        uint256 s0 = seniorToken.totalSupply();
        if (s0 == 0) return;

        uint256 maxAdditional = 0;
        if (TestConstants.SENIOR_CAP_NUMERATOR * v0 > TestConstants.SENIOR_CAP_DENOMINATOR * d0) {
            maxAdditional = TestConstants.SENIOR_CAP_NUMERATOR * v0 - TestConstants.SENIOR_CAP_DENOMINATOR * d0;
        }
        if (maxAdditional == 0) return;

        uint256 remaining = TestConstants.DEFAULT_INITIAL_BALANCE - seniorAssets;
        if (remaining == 0) return;
        uint256 limit = maxAdditional < remaining ? maxAdditional : remaining;
        uint256 additional = bound(uint256(additionalSeed), TestConstants.ONE_UNIT, limit);

        uint256 priceBefore = (d0 * TestConstants.ONE_WAD) / s0;
        _depositSenior(alice, additional);

        uint256 v1 = controller.previewV();
        uint256 d1 = controller.seniorDebt();
        uint256 s1 = seniorToken.totalSupply();
        uint256 seniorValue1 = v1 < d1 ? v1 : d1;
        uint256 priceAfter = (seniorValue1 * TestConstants.ONE_WAD) / s1;

        assertApproxEqAbs(priceBefore, priceAfter, TestConstants.PRICE_ASSERT_DELTA);
    }

    function testFuzz_juniorPrice_noJumpOnJuniorDeposit(uint96 juniorSeed, uint96 seniorSeed, uint96 additionalSeed)
        public
    {
        uint256 juniorAssets =
            bound(uint256(juniorSeed), TestConstants.FUZZ_MIN_ASSETS, TestConstants.FUZZ_MAX_JUNIOR_B);
        uint256 maxSenior = juniorAssets * TestConstants.SENIOR_CAP_NUMERATOR;
        if (maxSenior > TestConstants.FUZZ_MAX_SENIOR) maxSenior = TestConstants.FUZZ_MAX_SENIOR;
        uint256 seniorAssets = bound(uint256(seniorSeed), TestConstants.FUZZ_MIN_ASSETS, maxSenior);
        _depositJunior(bob, juniorAssets);
        _depositSenior(alice, seniorAssets);

        uint256 v0 = controller.previewV();
        uint256 d0 = controller.seniorDebt();
        if (v0 <= d0) return;

        uint256 j0 = juniorToken.totalSupply();
        if (j0 == 0) return;

        uint256 juniorValue0 = v0 - d0;
        uint256 priceBefore = (juniorValue0 * TestConstants.ONE_WAD) / j0;

        uint256 remaining = TestConstants.DEFAULT_INITIAL_BALANCE - juniorAssets;
        if (remaining == 0) return;
        uint256 additional = bound(uint256(additionalSeed), TestConstants.ONE_UNIT, remaining);

        _depositJunior(bob, additional);

        uint256 v1 = controller.previewV();
        uint256 d1 = controller.seniorDebt();
        uint256 j1 = juniorToken.totalSupply();
        uint256 juniorValue1 = v1 > d1 ? (v1 - d1) : 0;
        uint256 priceAfter = (juniorValue1 * TestConstants.ONE_WAD) / j1;

        assertApproxEqAbs(priceBefore, priceAfter, TestConstants.PRICE_ASSERT_DELTA);
    }

    // deposit helpers come from BaseTest
}
