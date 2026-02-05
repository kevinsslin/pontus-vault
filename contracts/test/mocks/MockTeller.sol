// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Minimal} from "../../src/interfaces/IERC20Minimal.sol";
import {MathUtils} from "../../src/libraries/MathUtils.sol";
import {SafeTransferLib} from "../../src/libraries/SafeTransferLib.sol";

contract MockTeller {
    using SafeTransferLib for IERC20Minimal;

    IERC20Minimal public immutable asset;
    uint8 public immutable decimals;

    uint256 public sharePriceWad = 1e18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(IERC20Minimal asset_) {
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
        shares = MathUtils.mulDivDown(assets, 1e18, sharePriceWad);
        _mint(receiver, shares);
    }

    function withdraw(uint256 assets, address receiver) external returns (uint256 sharesBurned) {
        sharesBurned = MathUtils.mulDivDown(assets, 1e18, sharePriceWad);
        _burn(msg.sender, sharesBurned);
        asset.safeTransfer(receiver, assets);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return MathUtils.mulDivDown(assets, 1e18, sharePriceWad);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return MathUtils.mulDivDown(assets, 1e18, sharePriceWad);
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return MathUtils.mulDivDown(shares, sharePriceWad, 1e18);
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
