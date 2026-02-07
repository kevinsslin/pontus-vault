// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title OpenFi Decoder And Sanitizer Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Decoder return format for OpenFi calls executed through manager + merkle verification.
interface IOpenFiDecoderAndSanitizer {
    /// @notice Decodes OpenFi pool supply call data.
    /// @param _asset Asset address.
    /// @param _amount Asset amount.
    /// @param _onBehalfOf Beneficiary.
    /// @param _referralCode OpenFi referral code.
    /// @return _packedAddresses Packed address list.
    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16 _referralCode)
        external
        pure
        returns (bytes memory _packedAddresses);

    /// @notice Decodes OpenFi pool withdraw call data.
    /// @param _asset Asset address.
    /// @param _amount Asset amount.
    /// @param _to Recipient.
    /// @return _packedAddresses Packed address list.
    function withdraw(address _asset, uint256 _amount, address _to)
        external
        pure
        returns (bytes memory _packedAddresses);
}
