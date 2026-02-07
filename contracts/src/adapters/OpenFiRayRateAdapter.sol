// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IRefRateProvider} from "../interfaces/IRefRateProvider.sol";
import {IOpenFiRateSource} from "../interfaces/IOpenFiRateSource.sol";

/// @title OpenFi RAY Rate Adapter
/// @notice Adapts OpenFi annualized RAY supply rates into per-second WAD rates.
contract OpenFiRayRateAdapter is IRefRateProvider, Ownable {
    /// @notice Emitted when an address input is zero.
    error ZeroAddress();

    /// @dev OpenFi RAY scale.
    uint256 internal constant RAY = 1e27;
    /// @dev Pontus WAD scale.
    uint256 internal constant WAD = 1e18;
    /// @dev Fixed denominator for annualized-to-per-second conversion.
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /// @notice External rate source returning annualized RAY rates.
    address public source;
    /// @notice Asset whose rate is requested from source.
    address public asset;

    /// @notice Emitted when OpenFi rate source is updated.
    /// @param oldSource Previous source contract.
    /// @param newSource New source contract.
    event SourceUpdated(address indexed oldSource, address indexed newSource);
    /// @notice Emitted when tracked asset is updated.
    /// @param oldAsset Previous asset address.
    /// @param newAsset New asset address.
    event AssetUpdated(address indexed oldAsset, address indexed newAsset);

    /// @notice Initializes adapter owner, source, and tracked asset.
    /// @param _owner Contract owner.
    /// @param _source OpenFi-compatible annualized rate source.
    /// @param _asset Underlying asset for rate query.
    constructor(address _owner, address _source, address _asset) Ownable(_owner) {
        if (_source == address(0)) revert ZeroAddress();
        if (_asset == address(0)) revert ZeroAddress();
        source = _source;
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates annualized rate source contract.
    /// @param _newSource New source address.
    function setSource(address _newSource) external onlyOwner {
        if (_newSource == address(0)) revert ZeroAddress();
        emit SourceUpdated(source, _newSource);
        source = _newSource;
    }

    /// @notice Updates tracked underlying asset.
    /// @param _newAsset New asset address.
    function setAsset(address _newAsset) external onlyOwner {
        if (_newAsset == address(0)) revert ZeroAddress();
        emit AssetUpdated(asset, _newAsset);
        asset = _newAsset;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRefRateProvider
    function getRatePerSecondWad() external view returns (uint256) {
        uint256 rateRayPerYear = IOpenFiRateSource(source).getSupplyRateRayPerYear(asset);
        return Math.mulDiv(rateRayPerYear, WAD, RAY * SECONDS_PER_YEAR);
    }
}
