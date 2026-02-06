// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTest} from "../BaseTest.sol";
import {MockTeller} from "../mocks/MockTeller.sol";
import {MockAccountant} from "../mocks/MockAccountant.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {TestConstants} from "../utils/Constants.sol";

contract TrancheHandler is Test {
    MockERC20 internal immutable asset;
    MockAccountant internal immutable accountant;
    TrancheController internal immutable controller;
    TrancheToken internal immutable seniorToken;
    TrancheToken internal immutable juniorToken;
    address internal immutable alice;
    address internal immutable bob;

    constructor(
        MockERC20 asset_,
        MockAccountant accountant_,
        TrancheController controller_,
        TrancheToken seniorToken_,
        TrancheToken juniorToken_,
        address alice_,
        address bob_
    ) {
        asset = asset_;
        accountant = accountant_;
        controller = controller_;
        seniorToken = seniorToken_;
        juniorToken = juniorToken_;
        alice = alice_;
        bob = bob_;
    }

    function depositSeniorAsAlice(uint256 amountSeed) external {
        uint256 balance = asset.balanceOf(alice);
        if (balance == 0) return;
        uint256 amount = bound(amountSeed, TestConstants.INVARIANT_MIN_BOUND, balance);
        vm.startPrank(alice);
        asset.approve(address(controller), amount);
        try controller.depositSenior(amount, alice) {} catch {}
        vm.stopPrank();
    }

    function depositJuniorAsBob(uint256 amountSeed) external {
        uint256 balance = asset.balanceOf(bob);
        if (balance == 0) return;
        uint256 amount = bound(amountSeed, TestConstants.INVARIANT_MIN_BOUND, balance);
        vm.startPrank(bob);
        asset.approve(address(controller), amount);
        try controller.depositJunior(amount, bob) {} catch {}
        vm.stopPrank();
    }

    function redeemSeniorAsAlice(uint256 shareSeed) external {
        uint256 shares = seniorToken.balanceOf(alice);
        if (shares == 0) return;
        uint256 redeemShares = bound(shareSeed, TestConstants.INVARIANT_MIN_BOUND, shares);
        vm.startPrank(alice);
        seniorToken.approve(address(controller), redeemShares);
        try controller.redeemSenior(redeemShares, alice) {} catch {}
        vm.stopPrank();
    }

    function redeemJuniorAsBob(uint256 shareSeed) external {
        uint256 shares = juniorToken.balanceOf(bob);
        if (shares == 0) return;
        uint256 redeemShares = bound(shareSeed, TestConstants.INVARIANT_MIN_BOUND, shares);
        vm.startPrank(bob);
        juniorToken.approve(address(controller), redeemShares);
        try controller.redeemJunior(redeemShares, bob) {} catch {}
        vm.stopPrank();
    }

    function updateRate(uint96 rateSeed) external {
        uint256 rate = bound(uint256(rateSeed), TestConstants.INVARIANT_RATE_MIN, TestConstants.INVARIANT_RATE_MAX);
        accountant.setRate(IERC20(address(asset)), rate);
    }
}

contract TrancheAccountingInvariantTest is StdInvariant, BaseTest {
    TrancheHandler internal handler;

    function setUp() public override {
        super.setUp();

        MockTeller teller = new MockTeller(IERC20(address(asset)), mockAccountant);
        _initController(address(teller), address(teller), TestConstants.ZERO_ADDRESS, address(mockAccountant));

        _seedBalances(TestConstants.DEFAULT_INITIAL_BALANCE);
        _depositJunior(bob, TestConstants.INVARIANT_JUNIOR_BOOTSTRAP);
        _depositSenior(alice, TestConstants.INVARIANT_SENIOR_BOOTSTRAP);

        handler = new TrancheHandler(asset, mockAccountant, controller, seniorToken, juniorToken, alice, bob);
        targetContract(address(handler));
    }

    function invariant_totalSupplyMatchesTrackedActors() public view {
        uint256 seniorSupply = seniorToken.totalSupply();
        uint256 juniorSupply = juniorToken.totalSupply();

        assertEq(seniorSupply, seniorToken.balanceOf(alice) + seniorToken.balanceOf(bob));
        assertEq(juniorSupply, juniorToken.balanceOf(alice) + juniorToken.balanceOf(bob));
    }

    function invariant_totalValueMatchesTranchePreviews() public view {
        uint256 seniorSupply = seniorToken.totalSupply();
        uint256 juniorSupply = juniorToken.totalSupply();

        uint256 seniorAssets = controller.previewRedeemSenior(seniorSupply);
        uint256 juniorAssets = controller.previewRedeemJunior(juniorSupply);
        uint256 total = seniorAssets + juniorAssets;
        uint256 v = controller.previewV();
        assertLe(total, v);
    }
}
