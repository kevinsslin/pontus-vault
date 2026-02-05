// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library TestConstants {
    uint8 internal constant USDC_DECIMALS = 6;
    uint8 internal constant BORING_VAULT_DECIMALS = 18;

    uint256 internal constant ONE_USDC = 1e6;
    uint256 internal constant ONE_SHARE = 1e18;
    uint256 internal constant ONE_WAD = 1e18;
    uint256 internal constant ASSET_TO_SHARE_SCALE = 1e12;

    uint256 internal constant DEFAULT_MAX_SENIOR_RATIO_BPS = 8_000;
    uint256 internal constant UPDATED_MAX_SENIOR_RATIO_BPS = 9_000;
    uint256 internal constant INVALID_BPS = 10_001;
    uint256 internal constant BPS_SCALE = 10_000;

    uint256 internal constant ACCOUNTANT_PAR_RATE = ONE_WAD;
    uint256 internal constant ACCOUNTANT_BULL_RATE = 11e17;
    uint256 internal constant ACCOUNTANT_BEAR_RATE = 7e17;

    uint256 internal constant ACCOUNTANT_PEGGED_SHARE_PRICE = ONE_USDC;
    uint256 internal constant ACCOUNTANT_UPPER_BOUND_BPS = 11_000;
    uint256 internal constant ACCOUNTANT_LOWER_BOUND_BPS = 9_000;

    uint256 internal constant DEFAULT_INITIAL_BALANCE = 1_000_000 * ONE_USDC;
    uint256 internal constant DEFAULT_JUNIOR_DEPOSIT = 200 * ONE_USDC;
    uint256 internal constant DEFAULT_SENIOR_DEPOSIT = 800 * ONE_USDC;
    uint256 internal constant DEFAULT_TOTAL_BORING_SHARES =
        (DEFAULT_JUNIOR_DEPOSIT + DEFAULT_SENIOR_DEPOSIT) * ASSET_TO_SHARE_SCALE;
    uint256 internal constant DEFAULT_JUNIOR_REMAINING_SHARES = 200 * ONE_SHARE;

    uint256 internal constant SMALL_DEPOSIT = 10 * ONE_USDC;
    uint256 internal constant SMALL_JUNIOR_DEPOSIT = 50 * ONE_USDC;
    uint256 internal constant SMALL_SHARES = 50 * ONE_USDC;
    uint256 internal constant ONE_UNIT = ONE_USDC;

    uint256 internal constant TOKEN_MINT_AMOUNT = 10 * ONE_USDC;
    uint256 internal constant TOKEN_TRANSFER_AMOUNT = 3 * ONE_USDC;
    uint256 internal constant TOKEN_APPROVE_AMOUNT = 2 * ONE_USDC;
    uint256 internal constant TOKEN_BURN_AMOUNT = 4 * ONE_USDC;
    uint256 internal constant TOKEN_BURN_APPROVAL = 6 * ONE_USDC;
    uint256 internal constant TOKEN_POST_BURN_SUPPLY = 6 * ONE_USDC;
    uint256 internal constant TOKEN_POST_BURN_ALLOWANCE = 2 * ONE_USDC;

    uint256 internal constant OPENFI_SUPPLY_AMOUNT = 1_250 * ONE_USDC;
    uint256 internal constant OPENFI_WITHDRAW_AMOUNT = 250 * ONE_USDC;
    uint256 internal constant OPENFI_FORK_ROUNDTRIP = 1_000 * ONE_USDC;

    uint256 internal constant ACCRUAL_TEST_RATE = 1e14;
    uint256 internal constant ACCRUAL_WARP_SECONDS = 3_600;
    uint256 internal constant PRICE_ASSERT_DELTA = 2;

    uint256 internal constant INVARIANT_JUNIOR_BOOTSTRAP = 200_000 * ONE_USDC;
    uint256 internal constant INVARIANT_SENIOR_BOOTSTRAP = 400_000 * ONE_USDC;

    uint256 internal constant FUZZ_MIN_ASSETS = 100 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_A = 300_000 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_B = 500_000 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_SENIOR = 800_000 * ONE_USDC;
}
