// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {
    BaseDecoderAndSanitizer
} from "../../lib/boring-vault/src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {IPontusDecoderAndSanitizer} from "../interfaces/manager/IPontusDecoderAndSanitizer.sol";

/// @title OpenFi Asseto Decoder And Sanitizer
/// @author Kevin Lin (@kevinsslin)
/// @notice Decoder/sanitizer implementation for OpenFi + Asseto manager actions.
/// @dev Returned bytes are used in manager merkle leaf hashing via `abi.encodePacked(...)`.
contract OpenFiAssetoDecoderAndSanitizer is BaseDecoderAndSanitizer, IPontusDecoderAndSanitizer {
    /// @notice Initializes decoder for a specific BoringVault context.
    /// @param _boringVault BoringVault managed by `ManagerWithMerkleVerification`.
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    /*//////////////////////////////////////////////////////////////
                             OPENFI DECODERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPontusDecoderAndSanitizer
    function supply(address _asset, uint256, address _onBehalfOf, uint16)
        external
        pure
        override
        returns (bytes memory _packedAddresses)
    {
        return abi.encodePacked(_asset, _onBehalfOf);
    }

    /// @inheritdoc IPontusDecoderAndSanitizer
    function withdraw(address _asset, uint256, address _to)
        external
        pure
        override
        returns (bytes memory _packedAddresses)
    {
        return abi.encodePacked(_asset, _to);
    }

    /*//////////////////////////////////////////////////////////////
                             ASSETO DECODERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPontusDecoderAndSanitizer
    function subscribe(address _uAddress, uint256) external pure override returns (bytes memory _packedAddresses) {
        return abi.encodePacked(_uAddress);
    }

    /// @inheritdoc IPontusDecoderAndSanitizer
    function redemption(address _uAddress, uint256) external pure override returns (bytes memory _packedAddresses) {
        return abi.encodePacked(_uAddress);
    }
}
