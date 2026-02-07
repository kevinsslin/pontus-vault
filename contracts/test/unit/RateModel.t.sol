// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICapSafetyRateModel} from "../../src/interfaces/rates/ICapSafetyRateModel.sol";
import {CapSafetyRateModel} from "../../src/rate-models/CapSafetyRateModel.sol";
import {FixedRateModel} from "../../src/rate-models/FixedRateModel.sol";
import {BaseTest} from "../BaseTest.sol";
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

contract RateModelTest is BaseTest {
    address internal owner;
    address internal outsider;

    MockRefRateProvider internal refProvider;

    function setUp() public override {
        BaseTest.setUp();
        owner = makeAddr("owner");
        outsider = makeAddr("outsider");
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
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
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
        vm.expectRevert(ICapSafetyRateModel.InvalidSafetyFactor.selector);
        new CapSafetyRateModel(owner, address(refProvider), TestConstants.CAP_MODEL_CAP, TestConstants.ONE_WAD + 1);
    }
}
