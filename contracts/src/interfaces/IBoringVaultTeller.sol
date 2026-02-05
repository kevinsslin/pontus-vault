// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";

/// @notice BoringVault teller interface used by TrancheController.
interface IBoringVaultTeller {
    function deposit(ERC20 asset, uint256 amount, uint256 minMint) external payable returns (uint256 shares);

    function bulkWithdraw(ERC20 asset, uint256 shareAmount, uint256 minAssets, address to)
        external
        returns (uint256 assetsOut);
}
