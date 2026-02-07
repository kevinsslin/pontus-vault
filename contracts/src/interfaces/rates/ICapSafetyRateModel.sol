// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRateModel} from "./IRateModel.sol";

/// @title Cap Safety Rate Model Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Public ABI for rate models that apply `min(cap, refRate * safetyFactor)`.
interface ICapSafetyRateModel is IRateModel {
    /// @notice Emitted when safety factor exceeds 1e18.
    error InvalidSafetyFactor();

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

    /// @notice Returns the configured cap in per-second WAD units.
    /// @return _capRatePerSecondWad Current cap value.
    function capRatePerSecondWad() external view returns (uint256 _capRatePerSecondWad);

    /// @notice Returns safety factor in WAD units.
    /// @return _safetyFactorWad Current safety factor.
    function safetyFactorWad() external view returns (uint256 _safetyFactorWad);

    /// @notice Returns reference rate provider address.
    /// @return _refRateProvider Current provider address.
    function refRateProvider() external view returns (address _refRateProvider);

    /// @notice Updates maximum cap rate.
    /// @param _newCap New per-second WAD cap.
    function setCapRatePerSecondWad(uint256 _newCap) external;

    /// @notice Updates safety factor multiplier.
    /// @param _newFactor New safety factor in WAD.
    function setSafetyFactorWad(uint256 _newFactor) external;

    /// @notice Updates reference rate provider.
    /// @param _newProvider New provider address.
    function setRefRateProvider(address _newProvider) external;
}
