// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal interface matching BoringVault's TellerWithMultiAssetSupport signatures.
interface IBoringVaultTeller {
    function deposit(IERC20 asset, uint256 amount, uint256 minMint) external payable returns (uint256 shares);

    function bulkWithdraw(
        IERC20 asset,
        uint256 shareAmount,
        uint256 minAssets,
        address to
    ) external returns (uint256 assetsOut);
}
