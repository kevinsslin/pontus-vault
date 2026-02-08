// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {console2} from "forge-std/console2.sol";

import {BoringVault} from "../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ERC20} from "../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";

import {BaseScript} from "./BaseScript.sol";

/// @title Update Exchange Rate
/// @author Kevin Lin (@kevinsslin)
/// @notice Updates BoringVault accountant exchange rate using current vault asset balance and share supply.
contract UpdateExchangeRate is BaseScript {
    uint256 internal constant BPS_SCALE = 10_000;

    /// @notice Runtime configuration sourced from environment variables.
    struct RunConfig {
        uint256 deployerKey;
        address vaultAddress;
        address accountantAddress;
        address assetAddress;
        uint256 minUpdateBps;
        bool allowPauseUpdate;
    }

    /// @notice Entry point for one exchange-rate update run.
    /// @dev Required env:
    ///      - `PRIVATE_KEY`
    ///      - `VAULT`
    ///      - `ACCOUNTANT`
    ///      - `ASSET`
    ///      Optional:
    ///      - `MIN_UPDATE_BPS` (default: 1)
    ///      - `ALLOW_PAUSE_UPDATE` (default: false)
    function run() external {
        RunConfig memory cfg = _loadRunConfig();

        BoringVault vault = BoringVault(payable(cfg.vaultAddress));
        AccountantWithRateProviders accountant = AccountantWithRateProviders(cfg.accountantAddress);
        ERC20 asset = ERC20(cfg.assetAddress);

        (bool hasSupply, uint256 nextExchangeRate) = _nextExchangeRate(vault, asset, cfg.vaultAddress);
        if (!hasSupply) {
            console2.log("skip: vault total supply is zero");
            return;
        }

        require(nextExchangeRate <= type(uint96).max, "exchange rate overflow");

        uint256 currentExchangeRate = accountant.getRate();
        if (_withinUpdateThreshold(currentExchangeRate, nextExchangeRate, cfg.minUpdateBps)) {
            console2.log("skip: delta below MIN_UPDATE_BPS");
            console2.log("currentRate", currentExchangeRate);
            console2.log("nextRate", nextExchangeRate);
            return;
        }

        (bool updateWillPause,,) = accountant.previewUpdateExchangeRate(uint96(nextExchangeRate));
        if (updateWillPause && !cfg.allowPauseUpdate) {
            revert("update would pause accountant");
        }

        vm.startBroadcast(cfg.deployerKey);
        accountant.updateExchangeRate(uint96(nextExchangeRate));
        vm.stopBroadcast();

        console2.log("accountant", cfg.accountantAddress);
        console2.log("vault", cfg.vaultAddress);
        console2.log("asset", cfg.assetAddress);
        console2.log("currentRate", currentExchangeRate);
        console2.log("nextRate", nextExchangeRate);
        console2.log("updateWillPause", updateWillPause);
    }

    /// @notice Loads and validates script configuration from environment.
    /// @return cfg Validated runtime configuration.
    function _loadRunConfig() internal view returns (RunConfig memory cfg) {
        cfg.deployerKey = _envUint("PRIVATE_KEY", 0);
        require(cfg.deployerKey != 0, "PRIVATE_KEY missing");

        cfg.vaultAddress = _envAddress("VAULT", address(0));
        cfg.accountantAddress = _envAddress("ACCOUNTANT", address(0));
        cfg.assetAddress = _envAddress("ASSET", address(0));
        _requireAddress(cfg.vaultAddress, "VAULT");
        _requireAddress(cfg.accountantAddress, "ACCOUNTANT");
        _requireAddress(cfg.assetAddress, "ASSET");

        cfg.minUpdateBps = _envUint("MIN_UPDATE_BPS", 1);
        cfg.allowPauseUpdate = vm.envOr("ALLOW_PAUSE_UPDATE", false);
    }

    /// @notice Calculates next exchange rate from current vault balance and total supply.
    /// @param _vault BoringVault instance.
    /// @param _asset Underlying asset configured in accountant.
    /// @param _vaultAddress Vault address used for asset balance reads.
    /// @return _hasSupply True when vault total supply is non-zero.
    /// @return _nextRate Next exchange rate candidate.
    function _nextExchangeRate(BoringVault _vault, ERC20 _asset, address _vaultAddress)
        internal
        view
        returns (bool _hasSupply, uint256 _nextRate)
    {
        uint256 vaultTotalSupply = _vault.totalSupply();
        if (vaultTotalSupply == 0) {
            return (false, 0);
        }

        uint256 vaultAssets = _asset.balanceOf(_vaultAddress);
        uint256 oneShare = 10 ** _vault.decimals();
        _nextRate = (vaultAssets * oneShare) / vaultTotalSupply;
        return (true, _nextRate);
    }

    /// @notice Returns true when exchange-rate delta is below configured threshold.
    function _withinUpdateThreshold(uint256 _currentRate, uint256 _nextRate, uint256 _minUpdateBps)
        internal
        pure
        returns (bool _isWithinThreshold)
    {
        if (_currentRate == 0 || _minUpdateBps == 0) return false;
        if (_currentRate == _nextRate) return true;

        uint256 delta = _currentRate > _nextRate ? _currentRate - _nextRate : _nextRate - _currentRate;
        uint256 deltaBps = (delta * BPS_SCALE) / _currentRate;
        return deltaBps < _minUpdateBps;
    }
}
