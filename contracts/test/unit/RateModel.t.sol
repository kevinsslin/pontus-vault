// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICapSafetyRateModel} from "../../src/interfaces/rates/ICapSafetyRateModel.sol";
import {CapSafetyRateModel} from "../../src/rate-models/CapSafetyRateModel.sol";
import {FixedRateModel} from "../../src/rate-models/FixedRateModel.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseTest} from "../BaseTest.sol";

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

    function test_fixed_rate_model_owner_can_update_rate() public {
        FixedRateModel model = new FixedRateModel(owner, TestDefaults.FIXED_RATE_INITIAL);
        assertEq(model.getRatePerSecondWad(), TestDefaults.FIXED_RATE_INITIAL);

        vm.prank(owner);
        model.setRatePerSecondWad(TestDefaults.FIXED_RATE_UPDATED);
        assertEq(model.getRatePerSecondWad(), TestDefaults.FIXED_RATE_UPDATED);
    }

    function test_fixed_rate_model_reverts_for_non_owner() public {
        FixedRateModel model = new FixedRateModel(owner, TestDefaults.FIXED_RATE_INITIAL);
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        model.setRatePerSecondWad(TestDefaults.FIXED_RATE_UPDATED);
    }

    function test_cap_safety_rate_model_applies_safety_factor_and_cap() public {
        CapSafetyRateModel model = new CapSafetyRateModel(
            owner, address(refProvider), TestDefaults.CAP_MODEL_CAP, TestDefaults.CAP_MODEL_SAFETY_DEFAULT
        );

        refProvider.setRatePerSecondWad(TestDefaults.CAP_MODEL_REF_LOW);
        assertEq(model.getRatePerSecondWad(), TestDefaults.CAP_MODEL_EXPECTED_LOW);

        refProvider.setRatePerSecondWad(TestDefaults.CAP_MODEL_REF_HIGH);
        assertEq(model.getRatePerSecondWad(), TestDefaults.CAP_MODEL_CAP);
    }

    function test_cap_safety_rate_model_owner_can_update_params() public {
        CapSafetyRateModel model = new CapSafetyRateModel(
            owner, address(refProvider), TestDefaults.CAP_MODEL_CAP, TestDefaults.CAP_MODEL_SAFETY_DEFAULT
        );

        vm.startPrank(owner);
        model.setCapRatePerSecondWad(TestDefaults.CAP_MODEL_REF_LOW);
        model.setSafetyFactorWad(TestDefaults.CAP_MODEL_SAFETY_UPDATED);
        model.setRefRateProvider(TestConstants.ZERO_ADDRESS);
        vm.stopPrank();

        assertEq(model.capRatePerSecondWad(), TestDefaults.CAP_MODEL_REF_LOW);
        assertEq(model.safetyFactorWad(), TestDefaults.CAP_MODEL_SAFETY_UPDATED);
        assertEq(model.refRateProvider(), TestConstants.ZERO_ADDRESS);
        assertEq(model.getRatePerSecondWad(), 0);
    }

    function test_cap_safety_rate_model_reverts_for_invalid_safety_factor() public {
        vm.expectRevert(ICapSafetyRateModel.InvalidSafetyFactor.selector);
        new CapSafetyRateModel(owner, address(refProvider), TestDefaults.CAP_MODEL_CAP, TestConstants.ONE_WAD + 1);
    }
}
