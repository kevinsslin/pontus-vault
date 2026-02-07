// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Asseto Product Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Minimal Asseto Cash+ style product ABI used by Pontus manager integrations.
interface IAssetoProduct {
    /// @notice Subscribes underlying into the Asseto product for a beneficiary account.
    /// @param _uAddress Beneficiary account tracked by Asseto.
    /// @param _uAmount Underlying amount to subscribe.
    function subscribe(address _uAddress, uint256 _uAmount) external;

    /// @notice Redeems product balance back into underlying for a beneficiary account.
    /// @param _uAddress Beneficiary account tracked by Asseto.
    /// @param _tokenAmount Product amount to redeem.
    function redemption(address _uAddress, uint256 _tokenAmount) external;

    /// @notice Returns whether product subscriptions are paused.
    /// @return _paused True if paused.
    function paused() external view returns (bool _paused);

    /// @notice Returns current product price.
    /// @return _price Product price scale is protocol-defined.
    function getPrice() external view returns (uint256 _price);
}
