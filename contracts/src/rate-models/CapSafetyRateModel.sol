// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IRateModel} from "../interfaces/IRateModel.sol";
import {IRefRateProvider} from "../interfaces/IRefRateProvider.sol";

/// @title Cap Safety Rate Model
/// @notice Computes `min(cap, refRate * safetyFactor)` in per-second WAD units.
contract CapSafetyRateModel is IRateModel, Ownable {
    /// @notice Emitted when safety factor exceeds 1e18.
    error InvalidSafetyFactor();

    /// @notice Maximum per-second WAD rate.
    uint256 public capRatePerSecondWad;
    /// @notice Multiplicative dampener scaled by 1e18, bounded to [0, 1e18].
    uint256 public safetyFactorWad;
    /// @notice Reference rate provider returning per-second WAD rate.
    address public refRateProvider;

    /// @notice Emitted when cap rate is updated.
    /// @param oldCap Previous cap.
    /// @param newCap New cap.
    event CapRateUpdated(uint256 oldCap, uint256 newCap);
    /// @notice Emitted when safety factor is updated.
    /// @param oldFactor Previous safety factor.
    /// @param newFactor New safety factor.
    event SafetyFactorUpdated(uint256 oldFactor, uint256 newFactor);
    /// @notice Emitted when reference rate provider is updated.
    /// @param oldProvider Previous provider.
    /// @param newProvider New provider.
    event RefRateProviderUpdated(address indexed oldProvider, address indexed newProvider);

    /// @notice Initializes cap model parameters.
    /// @param _owner Contract owner.
    /// @param _refRateProvider Reference rate provider.
    /// @param _capRatePerSecondWad Cap rate in per-second WAD.
    /// @param _safetyFactorWad Safety factor in WAD.
    constructor(address _owner, address _refRateProvider, uint256 _capRatePerSecondWad, uint256 _safetyFactorWad)
        Ownable(_owner)
    {
        _setRefRateProvider(_refRateProvider);
        _setCapRate(_capRatePerSecondWad);
        _setSafetyFactor(_safetyFactorWad);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates maximum cap rate.
    /// @param _newCap New per-second WAD cap.
    function setCapRatePerSecondWad(uint256 _newCap) external onlyOwner {
        _setCapRate(_newCap);
    }

    /// @notice Updates safety factor multiplier.
    /// @param _newFactor New safety factor in WAD.
    function setSafetyFactorWad(uint256 _newFactor) external onlyOwner {
        _setSafetyFactor(_newFactor);
    }

    /// @notice Updates reference rate provider.
    /// @param _newProvider New provider address.
    function setRefRateProvider(address _newProvider) external onlyOwner {
        _setRefRateProvider(_newProvider);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRateModel
    function getRatePerSecondWad() external view returns (uint256) {
        if (refRateProvider == address(0)) {
            return 0;
        }

        uint256 refRate = IRefRateProvider(refRateProvider).getRatePerSecondWad();
        uint256 adjusted = Math.mulDiv(refRate, safetyFactorWad, 1e18);
        return adjusted < capRatePerSecondWad ? adjusted : capRatePerSecondWad;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets cap rate and emits update event.
    /// @param _newCap New cap value.
    function _setCapRate(uint256 _newCap) internal {
        emit CapRateUpdated(capRatePerSecondWad, _newCap);
        capRatePerSecondWad = _newCap;
    }

    /// @notice Sets safety factor and enforces <= 1e18 bound.
    /// @param _newFactor New factor value.
    function _setSafetyFactor(uint256 _newFactor) internal {
        if (_newFactor > 1e18) revert InvalidSafetyFactor();
        emit SafetyFactorUpdated(safetyFactorWad, _newFactor);
        safetyFactorWad = _newFactor;
    }

    /// @notice Sets reference provider.
    /// @param _newProvider New provider address.
    function _setRefRateProvider(address _newProvider) internal {
        emit RefRateProviderUpdated(refRateProvider, _newProvider);
        refRateProvider = _newProvider;
    }
}
