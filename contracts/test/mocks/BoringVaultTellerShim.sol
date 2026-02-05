// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";

import {IBoringVaultTeller} from "../../src/interfaces/IBoringVaultTeller.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BoringVaultTellerShim is IBoringVaultTeller {
    using SafeERC20 for IERC20;

    BoringVault public immutable vault;
    AccountantWithRateProviders public immutable accountant;
    IERC20 public immutable asset;
    uint256 public immutable oneShare;

    constructor(BoringVault vault_, AccountantWithRateProviders accountant_, IERC20 asset_) {
        vault = vault_;
        accountant = accountant_;
        asset = asset_;
        oneShare = 10 ** vault_.decimals();
    }

    function deposit(IERC20 depositAsset, uint256 assets, uint256 minMint)
        external
        payable
        returns (uint256 shares)
    {
        require(depositAsset == asset, "ASSET");
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        shares = Math.mulDiv(assets, oneShare, rate);
        require(shares >= minMint, "MIN_MINT");

        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.forceApprove(address(vault), assets);

        vault.enter(address(this), ERC20(address(asset)), assets, msg.sender, shares);
    }

    function bulkWithdraw(IERC20 withdrawAsset, uint256 shareAmount, uint256 minAssets, address to)
        external
        returns (uint256 assetsOut)
    {
        require(withdrawAsset == asset, "ASSET");
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        assetsOut = Math.mulDiv(shareAmount, rate, oneShare);
        require(assetsOut >= minAssets, "MIN_ASSETS");
        vault.exit(to, ERC20(address(asset)), assetsOut, msg.sender, shareAmount);
    }
}
