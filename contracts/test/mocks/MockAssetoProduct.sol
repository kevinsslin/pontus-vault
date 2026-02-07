// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";

/// @title Mock Asseto Product
/// @author Kevin Lin (@kevinsslin)
/// @notice Test double for manager-driven Asseto subscribe/redemption flows.
contract MockAssetoProduct is IAssetoProduct {
    using SafeERC20 for IERC20;

    /// @notice Reverted when redeem request exceeds tracked balance.
    error InsufficientBalance();

    /// @notice Underlying token used by mock product.
    IERC20 public immutable asset;
    /// @inheritdoc IAssetoProduct
    bool public paused;
    /// @notice Total subscribed amount tracked by mock product.
    uint256 public totalSubscribed;

    mapping(address account => uint256 amount) internal _balanceByAccount;

    /// @notice Initializes mock product with one underlying asset.
    /// @param _asset Underlying ERC20 token.
    constructor(IERC20 _asset) {
        asset = _asset;
    }

    /// @inheritdoc IAssetoProduct
    function subscribe(address _uAddress, uint256 _uAmount) external override {
        asset.safeTransferFrom(msg.sender, address(this), _uAmount);
        _balanceByAccount[_uAddress] += _uAmount;
        totalSubscribed += _uAmount;
    }

    /// @inheritdoc IAssetoProduct
    function redemption(address _uAddress, uint256 _tokenAmount) external override {
        uint256 balance = _balanceByAccount[_uAddress];
        if (_tokenAmount > balance) revert InsufficientBalance();

        _balanceByAccount[_uAddress] = balance - _tokenAmount;
        totalSubscribed -= _tokenAmount;
        asset.safeTransfer(msg.sender, _tokenAmount);
    }

    /// @inheritdoc IAssetoProduct
    function getPrice() external pure override returns (uint256 _price) {
        return 1e18;
    }

    /// @notice Returns tracked product balance for account.
    /// @param _account Account key.
    /// @return _amount Tracked product balance.
    function balanceOf(address _account) external view returns (uint256 _amount) {
        return _balanceByAccount[_account];
    }

    /// @notice Updates paused state for negative-path tests.
    /// @param _paused New paused value.
    function setPaused(bool _paused) external {
        paused = _paused;
    }
}
