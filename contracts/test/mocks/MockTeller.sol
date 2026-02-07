// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockAccountant} from "./MockAccountant.sol";

contract MockTeller {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    MockAccountant public immutable accountant;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(IERC20 _asset, MockAccountant _accountant) {
        asset = _asset;
        accountant = _accountant;
        decimals = 18;
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

    function deposit(IERC20 depositAsset, uint256 assets, uint256 minMint) external returns (uint256 shares) {
        require(address(depositAsset) == address(asset), "ASSET");
        asset.safeTransferFrom(msg.sender, address(this), assets);

        uint256 rate = accountant.getRateInQuoteSafe(asset);
        shares = Math.mulDiv(assets, 10 ** decimals, rate);
        require(shares >= minMint, "MIN_MINT");
        _mint(msg.sender, shares);
    }

    function bulkWithdraw(IERC20 withdrawAsset, uint256 shareAmount, uint256 minAssets, address to)
        external
        returns (uint256 assetsOut)
    {
        require(address(withdrawAsset) == address(asset), "ASSET");
        _burn(msg.sender, shareAmount);

        uint256 rate = accountant.getRateInQuoteSafe(asset);
        assetsOut = Math.mulDiv(shareAmount, rate, 10 ** decimals);
        require(assetsOut >= minAssets, "MIN_ASSETS");
        asset.safeTransfer(to, assetsOut);
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
