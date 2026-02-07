// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITrancheToken is IERC20Metadata {
    error NotController();
    error ZeroAddress();
    error InsufficientAllowance();

    function controller() external view returns (address);
    function initialize(string calldata _name, string calldata _symbol, uint8 _decimals, address _controller) external;
    function mint(address _to, uint256 _amount) external;
    function burnFrom(address _from, uint256 _amount) external;
}
