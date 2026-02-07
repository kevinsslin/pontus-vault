// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IAssetoProduct} from "../interfaces/asseto/IAssetoProduct.sol";

/// @title Asseto Call Builder
/// @author Kevin Lin (@kevinsslin)
/// @notice Helper utilities to build canonical Asseto product calldata/selectors.
library AssetoCallBuilder {
    /// @notice Selector for `IAssetoProduct.subscribe`.
    bytes4 internal constant SUBSCRIBE_SELECTOR = IAssetoProduct.subscribe.selector;
    /// @notice Selector for `IAssetoProduct.redemption`.
    bytes4 internal constant REDEMPTION_SELECTOR = IAssetoProduct.redemption.selector;

    /// @notice Builds calldata for `IAssetoProduct.subscribe`.
    /// @param _uAddress Beneficiary account tracked by Asseto.
    /// @param _uAmount Underlying amount to subscribe.
    /// @return _calldata Encoded call data.
    function subscribeCalldata(address _uAddress, uint256 _uAmount) internal pure returns (bytes memory _calldata) {
        return abi.encodeWithSelector(SUBSCRIBE_SELECTOR, _uAddress, _uAmount);
    }

    /// @notice Builds calldata for `IAssetoProduct.redemption`.
    /// @param _uAddress Beneficiary account tracked by Asseto.
    /// @param _tokenAmount Product amount to redeem.
    /// @return _calldata Encoded call data.
    function redemptionCalldata(address _uAddress, uint256 _tokenAmount)
        internal
        pure
        returns (bytes memory _calldata)
    {
        return abi.encodeWithSelector(REDEMPTION_SELECTOR, _uAddress, _tokenAmount);
    }

    /// @notice Returns `subscribe` selector.
    /// @return _selector Selector bytes4.
    function subscribeSelector() internal pure returns (bytes4 _selector) {
        return SUBSCRIBE_SELECTOR;
    }

    /// @notice Returns `redemption` selector.
    /// @return _selector Selector bytes4.
    function redemptionSelector() internal pure returns (bytes4 _selector) {
        return REDEMPTION_SELECTOR;
    }
}
