// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {IOpenFiPool} from "../../src/interfaces/IOpenFiPool.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";
import {TestConstants} from "../utils/Constants.sol";

contract MockOpenFiPool is IOpenFiPool {
    address internal _supplyAsset;
    uint256 internal _supplyAmount;
    address internal _supplyOnBehalfOf;
    uint16 internal _supplyReferralCode;

    address internal _withdrawAsset;
    uint256 internal _withdrawAmount;
    address internal _withdrawTo;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        _supplyAsset = asset;
        _supplyAmount = amount;
        _supplyOnBehalfOf = onBehalfOf;
        _supplyReferralCode = referralCode;
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        _withdrawAsset = asset;
        _withdrawAmount = amount;
        _withdrawTo = to;
        return amount;
    }

    function supplyAsset() external view returns (address) {
        return _supplyAsset;
    }

    function supplyAmount() external view returns (uint256) {
        return _supplyAmount;
    }

    function supplyOnBehalfOf() external view returns (address) {
        return _supplyOnBehalfOf;
    }

    function supplyReferralCode() external view returns (uint16) {
        return _supplyReferralCode;
    }

    function withdrawAsset() external view returns (address) {
        return _withdrawAsset;
    }

    function withdrawAmount() external view returns (uint256) {
        return _withdrawAmount;
    }

    function withdrawTo() external view returns (address) {
        return _withdrawTo;
    }
}

contract OpenFiCallBuilderTest is Test {
    MockOpenFiPool internal pool;

    function setUp() public {
        pool = new MockOpenFiPool();
    }

    function test_selectors_matchOpenFiInterface() public pure {
        assertEq(OpenFiCallBuilder.supplySelector(), IOpenFiPool.supply.selector);
        assertEq(OpenFiCallBuilder.withdrawSelector(), IOpenFiPool.withdraw.selector);
    }

    function test_supplyCalldata_executesWithExpectedArguments() public {
        address asset = makeAddr("asset");
        address onBehalfOf = makeAddr("onBehalfOf");
        uint256 amount = TestConstants.OPENFI_SUPPLY_AMOUNT;

        (bool ok,) = address(pool).call(OpenFiCallBuilder.supplyCalldata(asset, amount, onBehalfOf));
        assertTrue(ok);
        assertEq(pool.supplyAsset(), asset);
        assertEq(pool.supplyAmount(), amount);
        assertEq(pool.supplyOnBehalfOf(), onBehalfOf);
        assertEq(pool.supplyReferralCode(), TestConstants.OPENFI_REFERRAL_CODE);
    }

    function test_withdrawCalldata_executesWithExpectedArguments() public {
        address asset = makeAddr("asset");
        address to = makeAddr("to");
        uint256 amount = TestConstants.OPENFI_WITHDRAW_AMOUNT;

        (bool ok,) = address(pool).call(OpenFiCallBuilder.withdrawCalldata(asset, amount, to));
        assertTrue(ok);
        assertEq(pool.withdrawAsset(), asset);
        assertEq(pool.withdrawAmount(), amount);
        assertEq(pool.withdrawTo(), to);
    }
}
