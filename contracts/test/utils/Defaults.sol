// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library TestDefaults {
    string internal constant ACTOR_OPERATOR = "operator";
    string internal constant ACTOR_GUARDIAN = "guardian";
    string internal constant ACTOR_ALICE = "alice";
    string internal constant ACTOR_BOB = "bob";

    string internal constant ASSET_NAME = "USDC";
    string internal constant ASSET_SYMBOL = "USDC";

    string internal constant BORING_VAULT_NAME = "Boring Vault";
    string internal constant BORING_VAULT_SYMBOL = "BV";

    string internal constant SENIOR_TOKEN_NAME = "Pontus Vault Senior USDC S1";
    string internal constant SENIOR_TOKEN_SYMBOL = "pvS-USDC";
    string internal constant JUNIOR_TOKEN_NAME = "Pontus Vault Junior USDC S1";
    string internal constant JUNIOR_TOKEN_SYMBOL = "pvJ-USDC";
    string internal constant TOKEN_REINIT_NAME = "Again";
    string internal constant TOKEN_REINIT_SYMBOL = "AGAIN";

    string internal constant LOG_SKIP_FORK = "PHAROS_ATLANTIC_RPC_URL not set; skipping OpenFi fork test.";
    string internal constant LOG_SKIP_ASSETO_FORK = "PHAROS_ATLANTIC_RPC_URL not set; skipping Asseto fork test.";
    string internal constant LOG_SKIP_MANAGER_FORK = "PHAROS_ATLANTIC_RPC_URL not set; skipping manager fork test.";
    string internal constant LOG_SKIP_ASSETO_MANAGER_FORK =
        "RUN_ASSETO_MANAGER_FORK not enabled; skipping Asseto manager write test.";

    bytes32 internal constant SAMPLE_PARAMS_HASH = keccak256("sample");
    bytes32 internal constant SAMPLE_PARAMS_HASH_2 = keccak256("sample-2");
}
