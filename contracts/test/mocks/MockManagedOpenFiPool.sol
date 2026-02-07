// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOpenFiPool} from "../../src/interfaces/openfi/IOpenFiPool.sol";

/// @title Mock Managed OpenFi Pool
/// @author Kevin Lin (@kevinsslin)
/// @notice Test double for manager-driven OpenFi supply/withdraw flows.
contract MockManagedOpenFiPool is IOpenFiPool {
    using SafeERC20 for IERC20;

    /// @notice Reverted when call asset is not configured asset.
    error UnsupportedAsset();

    /// @notice Underlying token used by mock pool.
    IERC20 public immutable asset;
    /// @notice Total supplied value held by mock pool.
    uint256 public totalSupplied;

    mapping(address account => uint256 amount) internal _suppliedBalance;

    /// @notice Initializes mock pool with one underlying asset.
    /// @param _asset Underlying ERC20 token.
    constructor(IERC20 _asset) {
        asset = _asset;
    }

    /// @inheritdoc IOpenFiPool
    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16) external override {
        _requireAsset(_asset);
        asset.safeTransferFrom(msg.sender, address(this), _amount);
        _suppliedBalance[_onBehalfOf] += _amount;
        totalSupplied += _amount;
    }

    /// @inheritdoc IOpenFiPool
    function withdraw(address _asset, uint256 _amount, address _to) external override returns (uint256 _withdrawn) {
        _requireAsset(_asset);
        uint256 supplied = _suppliedBalance[msg.sender];
        _withdrawn = _amount <= supplied ? _amount : supplied;
        _suppliedBalance[msg.sender] = supplied - _withdrawn;
        totalSupplied -= _withdrawn;
        asset.safeTransfer(_to, _withdrawn);
    }

    /// @notice Returns supplied balance tracked by mock for an account.
    /// @param _account Account key.
    /// @return _amount Supplied amount.
    function suppliedBalance(address _account) external view returns (uint256 _amount) {
        return _suppliedBalance[_account];
    }

    /// @notice Validates configured underlying asset.
    /// @param _asset Asset argument to validate.
    function _requireAsset(address _asset) private view {
        if (_asset != address(asset)) revert UnsupportedAsset();
    }
}
