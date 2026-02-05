// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";

import {IERC20Minimal} from "../../src/interfaces/IERC20Minimal.sol";
import {ITeller} from "../../src/interfaces/ITeller.sol";
import {MathUtils} from "../../src/libraries/MathUtils.sol";
import {SafeTransferLib} from "../../src/libraries/SafeTransferLib.sol";

contract BoringVaultTellerAdapter is ITeller {
    using SafeTransferLib for IERC20Minimal;

    BoringVault public immutable vault;
    AccountantWithRateProviders public immutable accountant;
    IERC20Minimal public immutable asset;
    uint256 public immutable oneShare;

    constructor(BoringVault vault_, AccountantWithRateProviders accountant_, IERC20Minimal asset_) {
        vault = vault_;
        accountant = accountant_;
        asset = asset_;
        oneShare = 10 ** vault_.decimals();
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        shares = MathUtils.mulDivDown(assets, oneShare, rate);

        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.forceApprove(address(vault), assets);

        vault.enter(address(this), ERC20(address(asset)), assets, receiver, shares);
    }

    function withdraw(uint256 assets, address receiver) external returns (uint256 sharesBurned) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        sharesBurned = MathUtils.mulDivDown(assets, oneShare, rate);

        vault.exit(receiver, ERC20(address(asset)), assets, msg.sender, sharesBurned);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return MathUtils.mulDivDown(assets, oneShare, rate);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return MathUtils.mulDivDown(assets, oneShare, rate);
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assetsOut) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        return MathUtils.mulDivDown(shares, rate, oneShare);
    }
}
