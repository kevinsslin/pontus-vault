// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITrancheToken {
    function totalSupply() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}
