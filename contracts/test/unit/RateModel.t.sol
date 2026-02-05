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
        FixedRateModel model = new FixedRateModel(owner, 100);
        assertEq(model.getRatePerSecondWad(), 100);

        vm.prank(owner);
        model.setRatePerSecondWad(250);
        assertEq(model.getRatePerSecondWad(), 250);
    }

    function test_fixedRateModel_revertsForNonOwner() public {
        FixedRateModel model = new FixedRateModel(owner, 100);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        model.setRatePerSecondWad(250);
    }

    function test_capSafetyRateModel_appliesSafetyFactorAndCap() public {
        CapSafetyRateModel model = new CapSafetyRateModel(owner, address(refProvider), 1000, 8e17);

        refProvider.setRatePerSecondWad(900);
        assertEq(model.getRatePerSecondWad(), 720);

        refProvider.setRatePerSecondWad(2_000);
        assertEq(model.getRatePerSecondWad(), 1000);
    }

    function test_capSafetyRateModel_ownerCanUpdateParams() public {
        CapSafetyRateModel model = new CapSafetyRateModel(owner, address(refProvider), 1000, 8e17);

        vm.startPrank(owner);
        model.setCapRatePerSecondWad(900);
        model.setSafetyFactorWad(5e17);
        model.setRefRateProvider(address(0));
        vm.stopPrank();

        assertEq(model.capRatePerSecondWad(), 900);
        assertEq(model.safetyFactorWad(), 5e17);
        assertEq(model.refRateProvider(), address(0));
        assertEq(model.getRatePerSecondWad(), 0);
    }

    function test_capSafetyRateModel_revertsForInvalidSafetyFactor() public {
        vm.expectRevert(CapSafetyRateModel.InvalidSafetyFactor.selector);
        new CapSafetyRateModel(owner, address(refProvider), 1000, TestConstants.ONE_WAD + 1);
    }
}
