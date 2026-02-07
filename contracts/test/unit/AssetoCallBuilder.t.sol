// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";
import {AssetoCallBuilder} from "../../src/libraries/AssetoCallBuilder.sol";

import {TestConstants} from "../utils/Constants.sol";

import {BaseTest} from "../BaseTest.sol";

contract MockAssetoProductCallTarget is IAssetoProduct {
    address internal _subscribeAddress;
    uint256 internal _subscribeAmount;
    address internal _redemptionAddress;
    uint256 internal _redemptionAmount;

    function subscribe(address _uAddress, uint256 _uAmount) external {
        _subscribeAddress = _uAddress;
        _subscribeAmount = _uAmount;
    }

    function redemption(address _uAddress, uint256 _tokenAmount) external {
        _redemptionAddress = _uAddress;
        _redemptionAmount = _tokenAmount;
    }

    function paused() external pure returns (bool) {
        return false;
    }

    function getPrice() external pure returns (uint256) {
        return 1e18;
    }

    function subscribeAddress() external view returns (address) {
        return _subscribeAddress;
    }

    function subscribeAmount() external view returns (uint256) {
        return _subscribeAmount;
    }

    function redemptionAddress() external view returns (address) {
        return _redemptionAddress;
    }

    function redemptionAmount() external view returns (uint256) {
        return _redemptionAmount;
    }
}

contract AssetoCallBuilderTest is BaseTest {
    MockAssetoProductCallTarget internal product;

    function setUp() public override {
        BaseTest.setUp();
        product = new MockAssetoProductCallTarget();
    }

    function test_selectors_matchAssetoInterface() public pure {
        assertEq(AssetoCallBuilder.subscribeSelector(), IAssetoProduct.subscribe.selector);
        assertEq(AssetoCallBuilder.redemptionSelector(), IAssetoProduct.redemption.selector);
    }

    function test_subscribeCalldata_executesWithExpectedArguments() public {
        address account = makeAddr("assetoAccount");
        uint256 amount = TestConstants.OPENFI_SUPPLY_AMOUNT;

        (bool ok,) = address(product).call(AssetoCallBuilder.subscribeCalldata(account, amount));
        assertTrue(ok);
        assertEq(product.subscribeAddress(), account);
        assertEq(product.subscribeAmount(), amount);
    }

    function test_redemptionCalldata_executesWithExpectedArguments() public {
        address account = makeAddr("assetoAccount");
        uint256 amount = TestConstants.OPENFI_WITHDRAW_AMOUNT;

        (bool ok,) = address(product).call(AssetoCallBuilder.redemptionCalldata(account, amount));
        assertTrue(ok);
        assertEq(product.redemptionAddress(), account);
        assertEq(product.redemptionAmount(), amount);
    }
}
