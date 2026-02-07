// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Pontus Decoder And Sanitizer Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Canonical decoder/sanitizer return format consumed by `ManagerWithMerkleVerification`.
/// @dev Each function returns `abi.encodePacked(...)` of address arguments that must be merkle-allowlisted.
interface IPontusDecoderAndSanitizer {
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
