// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IRefRateProvider} from "../interfaces/IRefRateProvider.sol";
import {IOpenFiRateSource} from "../interfaces/IOpenFiRateSource.sol";

contract OpenFiRayRateAdapter is IRefRateProvider, Ownable {
    error ZeroAddress();

    uint256 internal constant RAY = 1e27;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    address public source;
    address public asset;

    event SourceUpdated(address indexed oldSource, address indexed newSource);
    event AssetUpdated(address indexed oldAsset, address indexed newAsset);

    constructor(address _owner, address _source, address _asset) Ownable(_owner) {
        if (_source == address(0)) revert ZeroAddress();
        if (_asset == address(0)) revert ZeroAddress();
        source = _source;
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSource(address _newSource) external onlyOwner {
        if (_newSource == address(0)) revert ZeroAddress();
        emit SourceUpdated(source, _newSource);
        source = _newSource;
    }

    function setAsset(address _newAsset) external onlyOwner {
        if (_newAsset == address(0)) revert ZeroAddress();
        emit AssetUpdated(asset, _newAsset);
        asset = _newAsset;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRatePerSecondWad() external view returns (uint256) {
        uint256 rateRayPerYear = IOpenFiRateSource(source).getSupplyRateRayPerYear(asset);
        return Math.mulDiv(rateRayPerYear, WAD, RAY * SECONDS_PER_YEAR);
    }
}
