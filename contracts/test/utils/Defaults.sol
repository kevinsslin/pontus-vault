// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library TestDefaults {
    string internal constant ASSET_NAME = "USDC";
    string internal constant ASSET_SYMBOL = "USDC";

    string internal constant BORING_VAULT_NAME = "Boring Vault";
    string internal constant BORING_VAULT_SYMBOL = "BV";

    string internal constant SENIOR_TOKEN_NAME = "Pontus Vault Senior USDC S1";
    string internal constant SENIOR_TOKEN_SYMBOL = "pvS-USDC";
    string internal constant JUNIOR_TOKEN_NAME = "Pontus Vault Junior USDC S1";
    string internal constant JUNIOR_TOKEN_SYMBOL = "pvJ-USDC";

    bytes32 internal constant DEFAULT_PARAMS_HASH = keccak256("usdc-lending-s1");
}
