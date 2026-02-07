// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {
    BaseDecoderAndSanitizer
} from "../../lib/boring-vault/src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {IOpenFiDecoderAndSanitizer} from "../interfaces/decoders/IOpenFiDecoderAndSanitizer.sol";

/// @title OpenFi Decoder And Sanitizer
/// @author Kevin Lin (@kevinsslin)
/// @notice Decoder/sanitizer implementation for OpenFi manager actions.
/// @dev Returned bytes are used in manager merkle leaf hashing via `abi.encodePacked(...)`.
contract OpenFiDecoderAndSanitizer is BaseDecoderAndSanitizer, IOpenFiDecoderAndSanitizer {
    /// @notice Initializes decoder for a specific BoringVault context.
    /// @param _boringVault BoringVault managed by `ManagerWithMerkleVerification`.
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    /*//////////////////////////////////////////////////////////////
                             OPENFI DECODERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes OpenFi `supply` calldata and returns packed allowlist addresses.
    /// @param _asset OpenFi supply asset.
    /// @param _onBehalfOf OpenFi beneficiary account.
    /// @return _packedAddresses Packed address tuple `(asset, onBehalfOf)`.
    function supply(address _asset, uint256, address _onBehalfOf, uint16)
        external
        pure
        override
        returns (bytes memory _packedAddresses)
    {
        return abi.encodePacked(_asset, _onBehalfOf);
    }

    /// @notice Decodes OpenFi `withdraw` calldata and returns packed allowlist addresses.
    /// @param _asset OpenFi withdraw asset.
    /// @param _to OpenFi withdraw recipient.
    /// @return _packedAddresses Packed address tuple `(asset, to)`.
    function withdraw(address _asset, uint256, address _to)
        external
        pure
        override
        returns (bytes memory _packedAddresses)
    {
        return abi.encodePacked(_asset, _to);
    }
}
