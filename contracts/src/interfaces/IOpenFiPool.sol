// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IOpenFiPool {
    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16 _referralCode) external;
    function withdraw(address _asset, uint256 _amount, address _to) external returns (uint256);
}
