// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ITrancheToken} from "../interfaces/ITrancheToken.sol";

contract TrancheToken is Initializable, ERC20Upgradeable, ITrancheToken {
    error NotController();
    error ZeroAddress();
    error InsufficientAllowance();

    address public controller;
    uint8 private _tokenDecimals;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function initialize(string calldata _name, string calldata _symbol, uint8 _decimals, address _controller)
        external
        override
        initializer
    {
        if (_controller == address(0)) revert ZeroAddress();
        __ERC20_init(_name, _symbol);
        _tokenDecimals = _decimals;
        controller = _controller;
    }

    /*//////////////////////////////////////////////////////////////
                         CONTROLLER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address _to, uint256 _amount) external override {
        if (msg.sender != controller) revert NotController();
        _mint(_to, _amount);
    }

    function burnFrom(address _from, uint256 _amount) external override {
        if (msg.sender != controller) revert NotController();
        uint256 currentAllowance = allowance(_from, msg.sender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < _amount) revert InsufficientAllowance();
            _approve(_from, msg.sender, currentAllowance - _amount, true);
        }
        _burn(_from, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return _tokenDecimals;
    }
}
