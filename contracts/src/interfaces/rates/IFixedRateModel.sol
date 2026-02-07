// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRateModel} from "./IRateModel.sol";

/// @title Fixed Rate Model Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Public ABI for manually managed fixed per-second WAD rates.
interface IFixedRateModel is IRateModel {
    /// @notice Reserved error for zero-rate validation.
    error ZeroRate();

    /// @notice Emitted when fixed rate is updated.
    /// @param oldRate Previous rate.
    /// @param newRate New rate.
    event RateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Returns the configured fixed per-second WAD rate.
    /// @return _ratePerSecondWad Current fixed rate.
    function ratePerSecondWad() external view returns (uint256 _ratePerSecondWad);

    /// @notice Updates fixed rate value.
    /// @param _newRate New per-second WAD rate.
    function setRatePerSecondWad(uint256 _newRate) external;
}
