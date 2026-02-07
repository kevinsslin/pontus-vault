// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title OpenFi Rate Source Interface
/// @notice Protocol-facing source consumed by `OpenFiRayRateAdapter`.
/// @dev Return value must be annualized RAY (1e27) for the given asset.
interface IOpenFiRateSource {
    function getSupplyRateRayPerYear(address _asset) external view returns (uint256 _rateRayPerYear);
}
