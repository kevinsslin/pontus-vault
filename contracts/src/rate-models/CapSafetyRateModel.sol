// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ICapSafetyRateModel} from "../interfaces/rates/ICapSafetyRateModel.sol";
import {IRateModel} from "../interfaces/rates/IRateModel.sol";
import {IRefRateProvider} from "../interfaces/rates/IRefRateProvider.sol";

/// @title Cap Safety Rate Model
/// @author Kevin Lin (@kevinsslin)
/// @notice Computes `min(cap, refRate * safetyFactor)` in per-second WAD units.
contract CapSafetyRateModel is ICapSafetyRateModel, Ownable {
    /// @notice Maximum per-second WAD rate.
    uint256 public capRatePerSecondWad;
    /// @notice Multiplicative dampener scaled by 1e18, bounded to [0, 1e18].
    uint256 public safetyFactorWad;
    /// @notice Reference rate provider returning per-second WAD rate.
    address public refRateProvider;

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

    /// @inheritdoc ICapSafetyRateModel
    function setCapRatePerSecondWad(uint256 _newCap) external onlyOwner {
        _setCapRate(_newCap);
    }

    /// @inheritdoc ICapSafetyRateModel
    function setSafetyFactorWad(uint256 _newFactor) external onlyOwner {
        _setSafetyFactor(_newFactor);
    }

    /// @inheritdoc ICapSafetyRateModel
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
