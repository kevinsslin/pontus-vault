// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CapSafetyRateModel, FixedRateModel} from "../../src/tranche/RateModel.sol";
import {TestConstants} from "../utils/Constants.sol";

contract MockRefRateProvider {
    uint256 internal _rate;

    function setRatePerSecondWad(uint256 newRate) external {
        _rate = newRate;
    }

    function getRatePerSecondWad() external view returns (uint256) {
        return _rate;
    }
}

contract RateModelTest is Test {
    address internal owner;
    address internal alice;

    MockRefRateProvider internal refProvider;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        refProvider = new MockRefRateProvider();
    }

    function test_fixedRateModel_ownerCanUpdateRate() public {
        FixedRateModel model = new FixedRateModel(owner, TestConstants.FIXED_RATE_INITIAL);
        assertEq(model.getRatePerSecondWad(), TestConstants.FIXED_RATE_INITIAL);

        vm.prank(owner);
        model.setRatePerSecondWad(TestConstants.FIXED_RATE_UPDATED);
        assertEq(model.getRatePerSecondWad(), TestConstants.FIXED_RATE_UPDATED);
    }

    function test_fixedRateModel_revertsForNonOwner() public {
        FixedRateModel model = new FixedRateModel(owner, TestConstants.FIXED_RATE_INITIAL);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        model.setRatePerSecondWad(TestConstants.FIXED_RATE_UPDATED);
    }

    function test_capSafetyRateModel_appliesSafetyFactorAndCap() public {
        CapSafetyRateModel model = new CapSafetyRateModel(
            owner, address(refProvider), TestConstants.CAP_MODEL_CAP, TestConstants.CAP_MODEL_SAFETY_DEFAULT
        );

        refProvider.setRatePerSecondWad(TestConstants.CAP_MODEL_REF_LOW);
        assertEq(model.getRatePerSecondWad(), TestConstants.CAP_MODEL_EXPECTED_LOW);

        refProvider.setRatePerSecondWad(TestConstants.CAP_MODEL_REF_HIGH);
        assertEq(model.getRatePerSecondWad(), TestConstants.CAP_MODEL_CAP);
    }

    function test_capSafetyRateModel_ownerCanUpdateParams() public {
        CapSafetyRateModel model = new CapSafetyRateModel(
            owner, address(refProvider), TestConstants.CAP_MODEL_CAP, TestConstants.CAP_MODEL_SAFETY_DEFAULT
        );

        vm.startPrank(owner);
        model.setCapRatePerSecondWad(TestConstants.CAP_MODEL_REF_LOW);
        model.setSafetyFactorWad(TestConstants.CAP_MODEL_SAFETY_UPDATED);
        model.setRefRateProvider(TestConstants.ZERO_ADDRESS);
        vm.stopPrank();

        assertEq(model.capRatePerSecondWad(), TestConstants.CAP_MODEL_REF_LOW);
        assertEq(model.safetyFactorWad(), TestConstants.CAP_MODEL_SAFETY_UPDATED);
        assertEq(model.refRateProvider(), TestConstants.ZERO_ADDRESS);
        assertEq(model.getRatePerSecondWad(), 0);
    }

    function test_capSafetyRateModel_revertsForInvalidSafetyFactor() public {
        vm.expectRevert(CapSafetyRateModel.InvalidSafetyFactor.selector);
        new CapSafetyRateModel(owner, address(refProvider), TestConstants.CAP_MODEL_CAP, TestConstants.ONE_WAD + 1);
    }
}
