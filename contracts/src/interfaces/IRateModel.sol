// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Tranche Rate Model Interface
/// @notice Supplies normalized per-second WAD rates for senior debt accrual.
interface IRateModel {
    /// @notice Returns a per-second borrow rate scaled by 1e18.
    /// @return _ratePerSecondWad Current rate value.
    function getRatePerSecondWad() external view returns (uint256);
}
