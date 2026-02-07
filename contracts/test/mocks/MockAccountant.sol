// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAccountant {
    mapping(IERC20 => uint256) public rates;

    function setRate(IERC20 asset, uint256 rate) external {
        rates[asset] = rate;
    }

    function getRateInQuoteSafe(IERC20 asset) external view returns (uint256) {
        return rates[asset];
    }
}
