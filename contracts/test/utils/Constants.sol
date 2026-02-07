// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

library TestConstants {
    uint256 internal constant JAN_1_2026 = 1_767_225_600; // 2026-01-01 00:00:00 UTC

    uint8 internal constant MANAGER_ROLE = 1;
    uint8 internal constant STRATEGIST_ROLE = 2;
    uint8 internal constant MANAGER_INTERNAL_ROLE = 3;
    uint8 internal constant MANAGER_ADMIN_ROLE = 4;

    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_CALLER_ROLE = 9;
    uint256 internal constant DEFAULT_SENIOR_RATE_PER_SECOND_WAD = 0;
    address internal constant ZERO_ADDRESS = address(0);

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
    uint256 internal constant MANAGER_TEST_OPENFI_AMOUNT = 300 * ONE_USDC;
    uint256 internal constant MANAGER_TEST_ASSETO_AMOUNT = 200 * ONE_USDC;
    uint16 internal constant OPENFI_REFERRAL_CODE = 0;
    address internal constant OPENFI_POOL = 0xEC86f142E7334d99EEEF2c43298413299D919B30;
    address internal constant ASSETO_CASH_PLUS = 0x56f4add11d723412D27A9e9433315401B351d6E3;
    address internal constant PHAROS_USDC = 0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8;
    address internal constant PHAROS_USDT = 0xE7E84B8B4f39C507499c40B4ac199B050e2882d5;
    uint256 internal constant FORK_BALANCE_DUST_TOLERANCE = 1;

    uint256 internal constant ACCRUAL_TEST_RATE = 1e14;
    uint256 internal constant ACCRUAL_WARP_SECONDS = 3_600;
    uint256 internal constant PRICE_ASSERT_DELTA = 2;
    uint256 internal constant SMALL_SENIOR_MULTIPLIER = 10;
    uint256 internal constant UNDERWATER_SENIOR_ASSETS = 700 * ONE_USDC;
    uint256 internal constant ROLE_TEST_RATE = 1;
    uint256 internal constant HALF_POSITION = 2;
    uint256 internal constant SENIOR_UPSIDE_DIVISOR = 8;
    uint256 internal constant SENIOR_CAP_NUMERATOR = 4;
    uint256 internal constant SENIOR_CAP_DENOMINATOR = 5;

    uint24 internal constant ACCOUNTANT_MIN_UPDATE_DELAY_SECONDS = 0;
    uint16 internal constant ACCOUNTANT_PLATFORM_FEE = 0;
    uint16 internal constant ACCOUNTANT_PERFORMANCE_FEE = 0;
    uint16 internal constant TELLER_CREDIT_LIMIT = 0;

    uint256 internal constant FIXED_RATE_INITIAL = 100;
    uint256 internal constant FIXED_RATE_UPDATED = 250;
    uint256 internal constant CAP_MODEL_CAP = 1_000;
    uint256 internal constant CAP_MODEL_REF_LOW = 900;
    uint256 internal constant CAP_MODEL_REF_HIGH = 2_000;
    uint256 internal constant CAP_MODEL_SAFETY_DEFAULT = 8e17;
    uint256 internal constant CAP_MODEL_SAFETY_UPDATED = 5e17;
    uint256 internal constant CAP_MODEL_EXPECTED_LOW = 720;

    uint256 internal constant INVARIANT_MIN_BOUND = 1;
    uint256 internal constant INVARIANT_RATE_MIN = 6e17;
    uint256 internal constant INVARIANT_RATE_MAX = 12e17;

    uint256 internal constant INVARIANT_JUNIOR_BOOTSTRAP = 200_000 * ONE_USDC;
    uint256 internal constant INVARIANT_SENIOR_BOOTSTRAP = 400_000 * ONE_USDC;

    uint256 internal constant FUZZ_MIN_ASSETS = 100 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_A = 300_000 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_B = 500_000 * ONE_USDC;
    uint256 internal constant FUZZ_MAX_SENIOR = 800_000 * ONE_USDC;

    address internal constant CONFIG_ASSET = address(1);
    address internal constant CONFIG_VAULT = address(2);
    address internal constant CONFIG_TELLER = address(3);
    address internal constant CONFIG_ACCOUNTANT = address(4);
    address internal constant CONFIG_MANAGER = address(5);
    address internal constant CONFIG_OPERATOR = address(6);
    address internal constant CONFIG_GUARDIAN = address(7);

    address internal constant SAMPLE_CONTROLLER = address(0x1001);
    address internal constant SAMPLE_SENIOR_TOKEN = address(0x1002);
    address internal constant SAMPLE_JUNIOR_TOKEN = address(0x1003);
    address internal constant SAMPLE_VAULT = address(0x1004);
    address internal constant SAMPLE_TELLER = address(0x1005);
    address internal constant SAMPLE_ACCOUNTANT = address(0x1006);
    address internal constant SAMPLE_MANAGER = address(0x1007);
    address internal constant SAMPLE_ASSET = address(0x1008);
    address internal constant SAMPLE_CONTROLLER_ALT = address(0x2001);
}
