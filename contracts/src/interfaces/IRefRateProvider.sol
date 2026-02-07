// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Reference Rate Provider Interface
/// @notice Canonical adapter interface consumed by `CapSafetyRateModel`.
/// @dev Implementations must return a per-second rate scaled as WAD (1e18).
///      External protocols (for example OpenFi/Aave) generally do not implement
///      this interface directly. Use an adapter contract that reads protocol-
///      specific rates and normalizes them into this format.
interface IRefRateProvider {
    /// @notice Returns the normalized reference rate in per-second WAD units.
    function getRatePerSecondWad() external view returns (uint256);
}
