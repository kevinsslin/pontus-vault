// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {
    BaseDecoderAndSanitizer
} from "../../lib/boring-vault/src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {IAssetoDecoderAndSanitizer} from "../interfaces/decoders/IAssetoDecoderAndSanitizer.sol";

/// @title Asseto Decoder And Sanitizer
/// @author Kevin Lin (@kevinsslin)
/// @notice Decoder/sanitizer implementation for Asseto manager actions.
/// @dev Returned bytes are used in manager merkle leaf hashing via `abi.encodePacked(...)`.
contract AssetoDecoderAndSanitizer is BaseDecoderAndSanitizer, IAssetoDecoderAndSanitizer {
    /// @notice Initializes decoder for a specific BoringVault context.
    /// @param _boringVault BoringVault managed by `ManagerWithMerkleVerification`.
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    /*//////////////////////////////////////////////////////////////
                             ASSETO DECODERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes Asseto `subscribe` calldata and returns packed allowlist addresses.
    /// @param _uAddress Asseto beneficiary account.
    /// @return _packedAddresses Packed address tuple `(uAddress)`.
    function subscribe(address _uAddress, uint256) external pure override returns (bytes memory _packedAddresses) {
        return abi.encodePacked(_uAddress);
    }

    /// @notice Decodes Asseto `redemption` calldata and returns packed allowlist addresses.
    /// @param _uAddress Asseto beneficiary account.
    /// @return _packedAddresses Packed address tuple `(uAddress)`.
    function redemption(address _uAddress, uint256) external pure override returns (bytes memory _packedAddresses) {
        return abi.encodePacked(_uAddress);
    }
}
