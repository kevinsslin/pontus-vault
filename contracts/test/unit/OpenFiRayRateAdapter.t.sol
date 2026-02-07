// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OpenFiRayRateAdapter} from "../../src/adapters/OpenFiRayRateAdapter.sol";
import {IOpenFiRateSource} from "../../src/interfaces/openfi/IOpenFiRateSource.sol";

import {BaseTest} from "../BaseTest.sol";

contract MockOpenFiRateSource is IOpenFiRateSource {
    mapping(address asset => uint256 rateRayPerYear) internal _rates;

    function setSupplyRateRayPerYear(address _asset, uint256 _rateRayPerYear) external {
        _rates[_asset] = _rateRayPerYear;
    }

    function getSupplyRateRayPerYear(address _asset) external view returns (uint256 _rateRayPerYear) {
        return _rates[_asset];
    }
}

contract OpenFiRayRateAdapterTest is BaseTest {
    uint256 internal constant RAY = 1e27;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    address internal owner;
    address internal outsider;
    address internal rateAsset;
    MockOpenFiRateSource internal source;
    OpenFiRayRateAdapter internal adapter;

    function setUp() public override {
        BaseTest.setUp();
        owner = makeAddr("owner");
        outsider = makeAddr("outsider");
        rateAsset = makeAddr("asset");

        source = new MockOpenFiRateSource();
        adapter = new OpenFiRayRateAdapter(owner, address(source), rateAsset);
    }

    function test_getRatePerSecondWad_convertsRayPerYear() public {
        uint256 rateRayPerYear = 5e25; // 5% in RAY.
        source.setSupplyRateRayPerYear(rateAsset, rateRayPerYear);

        uint256 expected = Math.mulDiv(rateRayPerYear, WAD, RAY * SECONDS_PER_YEAR);
        assertEq(adapter.getRatePerSecondWad(), expected);
    }

    function test_setSource_onlyOwner() public {
        MockOpenFiRateSource newSource = new MockOpenFiRateSource();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        adapter.setSource(address(newSource));

        vm.prank(owner);
        adapter.setSource(address(newSource));
        assertEq(adapter.source(), address(newSource));
    }

    function test_setAsset_onlyOwner() public {
        address newAsset = makeAddr("newAsset");

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        adapter.setAsset(newAsset);

        vm.prank(owner);
        adapter.setAsset(newAsset);
        assertEq(adapter.asset(), newAsset);
    }

    function test_constructor_revertsOnZeroSource() public {
        vm.expectRevert(OpenFiRayRateAdapter.ZeroAddress.selector);
        new OpenFiRayRateAdapter(owner, address(0), rateAsset);
    }

    function test_constructor_revertsOnZeroAsset() public {
        vm.expectRevert(OpenFiRayRateAdapter.ZeroAddress.selector);
        new OpenFiRayRateAdapter(owner, address(source), address(0));
    }
}
