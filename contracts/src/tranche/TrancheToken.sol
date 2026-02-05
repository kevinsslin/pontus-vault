// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TrancheToken is Initializable, ERC20Upgradeable {
    error NotController();
    error ZeroAddress();
    error InsufficientAllowance();

    address public controller;
    uint8 private _tokenDecimals;

    function initialize(string calldata name_, string calldata symbol_, uint8 decimals_, address controller_)
        external
        initializer
    {
        if (controller_ == address(0)) revert ZeroAddress();
        __ERC20_init(name_, symbol_);
        _tokenDecimals = decimals_;
        controller = controller_;
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != controller) revert NotController();
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        if (msg.sender != controller) revert NotController();
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            _approve(from, msg.sender, currentAllowance - amount, true);
        }
        _burn(from, amount);
    }
}
