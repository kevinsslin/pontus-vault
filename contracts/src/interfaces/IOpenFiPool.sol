// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title OpenFi Pool Interface
/// @notice Minimal pool actions used by Pontus vault integrations.
interface IOpenFiPool {
    /// @notice Supplies asset liquidity into the OpenFi pool.
    /// @param _asset ERC20 asset address.
    /// @param _amount Asset amount to supply.
    /// @param _onBehalfOf Beneficiary that receives pool accounting.
    /// @param _referralCode Integrator referral code.
    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16 _referralCode) external;

    /// @notice Withdraws asset liquidity from the OpenFi pool.
    /// @param _asset ERC20 asset address.
    /// @param _amount Asset amount to withdraw.
    /// @param _to Recipient address for withdrawn assets.
    /// @return _withdrawn Actual withdrawn amount.
    function withdraw(address _asset, uint256 _amount, address _to) external returns (uint256);
}
