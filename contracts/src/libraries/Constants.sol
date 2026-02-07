// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Protocol Constants
/// @author Kevin Lin (@kevinsslin)
/// @notice Shared fixed-point and ratio constants used across tranche contracts.
library Constants {
    /// @notice 1e18 fixed-point scaling factor.
    uint256 internal constant WAD = 1e18;
    /// @notice Basis points denominator.
    uint256 internal constant BPS = 10_000;
}
