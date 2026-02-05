// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library OpenFiCallBuilder {
    bytes4 internal constant SUPPLY_SELECTOR = bytes4(keccak256("supply(address,uint256,address,uint16)"));
    bytes4 internal constant WITHDRAW_SELECTOR = bytes4(keccak256("withdraw(address,uint256,address)"));

    function supplyCalldata(address asset, uint256 amount, address onBehalfOf) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SUPPLY_SELECTOR, asset, amount, onBehalfOf, uint16(0));
    }

    function withdrawCalldata(address asset, uint256 amount, address to) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(WITHDRAW_SELECTOR, asset, amount, to);
    }

    function supplySelector() internal pure returns (bytes4) {
        return SUPPLY_SELECTOR;
    }

    function withdrawSelector() internal pure returns (bytes4) {
        return WITHDRAW_SELECTOR;
    }
}
