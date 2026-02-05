// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {TrancheController} from "../src/tranche/TrancheController.sol";
import {TrancheToken} from "../src/tranche/TrancheToken.sol";

abstract contract BaseTrancheTest is Test {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint256 internal constant DEFAULT_MAX_SENIOR_RATIO_BPS = 8000;

    // Rules mirror the high-level invariants we expect for any tranche product.
    struct RuleSet {
        uint256 maxSeniorRatioBps;
        uint256 seniorRatePerSecondWad;
    }

    RuleSet internal rules;

    address internal operator;
    address internal guardian;
    address internal alice;
    address internal bob;

    MockERC20 internal asset;
    TrancheController internal controller;
    TrancheToken internal seniorToken;
    TrancheToken internal juniorToken;

    function _initActors() internal {
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function _initRules() internal {
        rules = RuleSet({
            maxSeniorRatioBps: DEFAULT_MAX_SENIOR_RATIO_BPS,
            seniorRatePerSecondWad: 0
        });
    }

    function _deployCore(string memory name, string memory symbol, uint8 decimals) internal {
        asset = new MockERC20(name, symbol, decimals);
        controller = new TrancheController();
        seniorToken = new TrancheToken();
        juniorToken = new TrancheToken();

        seniorToken.initialize("Pontus Vault Senior USDC S1", "pvS-USDC", decimals, address(controller));
        juniorToken.initialize("Pontus Vault Junior USDC S1", "pvJ-USDC", decimals, address(controller));
    }

    function _initController(address vault, address teller, address rateModel) internal {
        controller.initialize(
            address(asset),
            vault,
            teller,
            operator,
            guardian,
            address(seniorToken),
            address(juniorToken),
            rules.seniorRatePerSecondWad,
            rateModel,
            rules.maxSeniorRatioBps
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
