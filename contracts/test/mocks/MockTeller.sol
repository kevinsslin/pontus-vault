// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockTeller {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    uint8 public immutable decimals;

    uint256 public sharePriceWad = 1e18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(IERC20 asset_) {
        asset = asset_;
        decimals = 18;
    }

    function setSharePriceWad(uint256 newPrice) external {
        sharePriceWad = newPrice;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ALLOWANCE");
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        asset.safeTransferFrom(msg.sender, address(this), assets);
        shares = Math.mulDiv(assets, 1e18, sharePriceWad);
        _mint(receiver, shares);
    }

    function withdraw(uint256 assets, address receiver) external returns (uint256 sharesBurned) {
        sharesBurned = Math.mulDiv(assets, 1e18, sharePriceWad);
        _burn(msg.sender, sharesBurned);
        asset.safeTransfer(receiver, assets);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return Math.mulDiv(assets, 1e18, sharePriceWad);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return Math.mulDiv(assets, 1e18, sharePriceWad);
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return Math.mulDiv(shares, sharePriceWad, 1e18);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BALANCE");
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "BALANCE");
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
