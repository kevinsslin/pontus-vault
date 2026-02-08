// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITrancheController} from "../src/interfaces/tranche/ITrancheController.sol";
import {TrancheController} from "../src/tranche/TrancheController.sol";
import {TrancheToken} from "../src/tranche/TrancheToken.sol";

import {MockAccountant} from "./mocks/MockAccountant.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {TestConstants} from "./utils/Constants.sol";
import {TestDefaults} from "./utils/Defaults.sol";

abstract contract BaseTest is Test {
    // Rules mirror the high-level invariants we expect for any tranche product.
    struct RuleSet {
        uint256 maxSeniorRatioBps;
        uint256 seniorRatePerSecondWad;
        uint256 maxRateAge;
    }

    RuleSet internal rules;

    address internal operator;
    address internal guardian;
    address internal alice;
    address internal bob;

    MockERC20 internal asset;
    MockAccountant internal mockAccountant;
    TrancheController internal controller;
    TrancheToken internal seniorToken;
    TrancheToken internal juniorToken;

    function setUp() public virtual {
        vm.warp(TestConstants.JAN_1_2026);
        _initActors();
        _initRules();
        _deployCore();
    }

    function _initActors() internal {
        operator = makeAddr(TestDefaults.ACTOR_OPERATOR);
        guardian = makeAddr(TestDefaults.ACTOR_GUARDIAN);
        alice = makeAddr(TestDefaults.ACTOR_ALICE);
        bob = makeAddr(TestDefaults.ACTOR_BOB);
    }

    function _initRules() internal {
        rules = RuleSet({
            maxSeniorRatioBps: TestDefaults.DEFAULT_MAX_SENIOR_RATIO_BPS,
            seniorRatePerSecondWad: TestDefaults.DEFAULT_SENIOR_RATE_PER_SECOND_WAD,
            maxRateAge: TestDefaults.DEFAULT_MAX_RATE_AGE
        });
    }

    function _deployCore() internal {
        asset = new MockERC20(TestDefaults.ASSET_NAME, TestDefaults.ASSET_SYMBOL, TestConstants.USDC_DECIMALS);
        mockAccountant = new MockAccountant();
        controller = new TrancheController();
        seniorToken = new TrancheToken();
        juniorToken = new TrancheToken();

        seniorToken.initialize(
            TestDefaults.SENIOR_TOKEN_NAME,
            TestDefaults.SENIOR_TOKEN_SYMBOL,
            TestConstants.USDC_DECIMALS,
            address(controller)
        );
        juniorToken.initialize(
            TestDefaults.JUNIOR_TOKEN_NAME,
            TestDefaults.JUNIOR_TOKEN_SYMBOL,
            TestConstants.USDC_DECIMALS,
            address(controller)
        );

        mockAccountant.setRate(IERC20(address(asset)), TestDefaults.ACCOUNTANT_PAR_RATE);
    }

    function _initController(address vault, address teller, address rateModel, address accountantAddress) internal {
        controller.initialize(
            ITrancheController.InitParams({
                asset: address(asset),
                vault: vault,
                teller: teller,
                accountant: accountantAddress,
                operator: operator,
                guardian: guardian,
                seniorToken: address(seniorToken),
                juniorToken: address(juniorToken),
                seniorRatePerSecondWad: rules.seniorRatePerSecondWad,
                rateModel: rateModel,
                maxSeniorRatioBps: rules.maxSeniorRatioBps,
                maxRateAge: rules.maxRateAge
            })
        );
    }

    function _seedBalances(uint256 amount) internal {
        asset.mint(alice, amount);
        asset.mint(bob, amount);
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
