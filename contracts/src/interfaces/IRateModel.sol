// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRateModel {
    function getRatePerSecondWad() external view returns (uint256);
}
