// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";

import {ITeller} from "../../src/interfaces/ITeller.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BoringVaultTellerAdapter is ITeller {
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

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        shares = Math.mulDiv(assets, oneShare, rate);

        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.forceApprove(address(vault), assets);

        vault.enter(address(this), ERC20(address(asset)), assets, receiver, shares);
    }

    function withdraw(uint256 assets, address receiver) external returns (uint256 sharesBurned) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        sharesBurned = Math.mulDiv(assets, oneShare, rate);

        vault.exit(receiver, ERC20(address(asset)), assets, msg.sender, sharesBurned);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return Math.mulDiv(assets, oneShare, rate);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return Math.mulDiv(assets, oneShare, rate);
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assetsOut) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return Math.mulDiv(shares, rate, oneShare);
    }
}
