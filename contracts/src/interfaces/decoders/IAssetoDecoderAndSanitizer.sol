// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Asseto Decoder And Sanitizer Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Decoder return format for Asseto calls executed through manager + merkle verification.
interface IAssetoDecoderAndSanitizer {
    /// @notice Decodes Asseto subscribe call data.
    /// @param _uAddress Beneficiary account.
    /// @param _uAmount Subscription amount.
    /// @return _packedAddresses Packed address list.
    function subscribe(address _uAddress, uint256 _uAmount) external pure returns (bytes memory _packedAddresses);

    /// @notice Decodes Asseto redemption call data.
    /// @param _uAddress Beneficiary account.
    /// @param _tokenAmount Redemption amount.
    /// @return _packedAddresses Packed address list.
    function redemption(address _uAddress, uint256 _tokenAmount) external pure returns (bytes memory _packedAddresses);
}
