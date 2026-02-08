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
        uint256 deployerKey = _envUint("PRIVATE_KEY", 0);
        require(deployerKey != 0, "PRIVATE_KEY missing");

        address vaultAddress = _envAddress("VAULT", address(0));
        address accountantAddress = _envAddress("ACCOUNTANT", address(0));
        address assetAddress = _envAddress("ASSET", address(0));
        _requireAddress(vaultAddress, "VAULT");
        _requireAddress(accountantAddress, "ACCOUNTANT");
        _requireAddress(assetAddress, "ASSET");

        uint256 minUpdateBps = _envUint("MIN_UPDATE_BPS", 1);
        bool allowPauseUpdate = vm.envOr("ALLOW_PAUSE_UPDATE", false);

        BoringVault vault = BoringVault(payable(vaultAddress));
        AccountantWithRateProviders accountant = AccountantWithRateProviders(accountantAddress);
        ERC20 asset = ERC20(assetAddress);

        uint256 vaultTotalSupply = vault.totalSupply();
        if (vaultTotalSupply == 0) {
            console2.log("skip: vault total supply is zero");
            return;
        }

        uint256 vaultAssets = asset.balanceOf(vaultAddress);
        uint256 oneShare = 10 ** vault.decimals();
        uint256 nextExchangeRate = (vaultAssets * oneShare) / vaultTotalSupply;
        require(nextExchangeRate <= type(uint96).max, "exchange rate overflow");

        uint256 currentExchangeRate = accountant.getRate();
        if (_withinUpdateThreshold(currentExchangeRate, nextExchangeRate, minUpdateBps)) {
            console2.log("skip: delta below MIN_UPDATE_BPS");
            console2.log("currentRate", currentExchangeRate);
            console2.log("nextRate", nextExchangeRate);
            return;
        }

        (bool updateWillPause,,) = accountant.previewUpdateExchangeRate(uint96(nextExchangeRate));
        if (updateWillPause && !allowPauseUpdate) {
            revert("update would pause accountant");
        }

        vm.startBroadcast(deployerKey);
        accountant.updateExchangeRate(uint96(nextExchangeRate));
        vm.stopBroadcast();

        console2.log("accountant", accountantAddress);
        console2.log("vault", vaultAddress);
        console2.log("asset", assetAddress);
        console2.log("currentRate", currentExchangeRate);
        console2.log("nextRate", nextExchangeRate);
        console2.log("updateWillPause", updateWillPause);
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
