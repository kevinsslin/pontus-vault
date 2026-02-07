// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IOpenFiPool} from "../interfaces/IOpenFiPool.sol";

library OpenFiCallBuilder {
    bytes4 internal constant SUPPLY_SELECTOR = IOpenFiPool.supply.selector;
    bytes4 internal constant WITHDRAW_SELECTOR = IOpenFiPool.withdraw.selector;

    function supplyCalldata(address _asset, uint256 _amount, address _onBehalfOf) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SUPPLY_SELECTOR, _asset, _amount, _onBehalfOf, uint16(0));
    }

    function withdrawCalldata(address _asset, uint256 _amount, address _to) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(WITHDRAW_SELECTOR, _asset, _amount, _to);
    }

    function supplySelector() internal pure returns (bytes4) {
        return SUPPLY_SELECTOR;
    }

    function withdrawSelector() internal pure returns (bytes4) {
        return WITHDRAW_SELECTOR;
    }
}
