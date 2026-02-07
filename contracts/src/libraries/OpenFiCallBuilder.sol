// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IOpenFiPool} from "../interfaces/openfi/IOpenFiPool.sol";

/// @title OpenFi Call Builder
/// @author Kevin Lin (@kevinsslin)
/// @notice Helper utilities to build canonical OpenFi pool calldata/selectors.
library OpenFiCallBuilder {
    /// @notice Selector for `IOpenFiPool.supply`.
    bytes4 internal constant SUPPLY_SELECTOR = IOpenFiPool.supply.selector;
    /// @notice Selector for `IOpenFiPool.withdraw`.
    bytes4 internal constant WITHDRAW_SELECTOR = IOpenFiPool.withdraw.selector;

    /// @notice Builds calldata for `IOpenFiPool.supply` with zero referral code.
    /// @param _asset Asset address.
    /// @param _amount Amount to supply.
    /// @param _onBehalfOf Beneficiary address.
    /// @return _calldata Encoded call data.
    function supplyCalldata(address _asset, uint256 _amount, address _onBehalfOf) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SUPPLY_SELECTOR, _asset, _amount, _onBehalfOf, uint16(0));
    }

    /// @notice Builds calldata for `IOpenFiPool.withdraw`.
    /// @param _asset Asset address.
    /// @param _amount Amount to withdraw.
    /// @param _to Recipient of withdrawn assets.
    /// @return _calldata Encoded call data.
    function withdrawCalldata(address _asset, uint256 _amount, address _to) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(WITHDRAW_SELECTOR, _asset, _amount, _to);
    }

    /// @notice Returns `supply` selector.
    /// @return _selector Selector bytes4.
    function supplySelector() internal pure returns (bytes4) {
        return SUPPLY_SELECTOR;
    }

    /// @notice Returns `withdraw` selector.
    /// @return _selector Selector bytes4.
    function withdrawSelector() internal pure returns (bytes4) {
        return WITHDRAW_SELECTOR;
    }
}
