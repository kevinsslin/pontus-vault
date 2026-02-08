// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {TestConstants} from "./Constants.sol";

/// @title Test Defaults
/// @author Kevin Lin (@kevinsslin)
/// @notice Scenario defaults, test fixtures and magic numbers chosen by this repo.
/// @dev Move values here when they are policy-dependent and can reasonably change per scenario.
library TestDefaults {
    /*//////////////////////////////////////////////////////////////
                             ACTOR LABELS
    //////////////////////////////////////////////////////////////*/

    string internal constant ACTOR_OPERATOR = "operator";
    string internal constant ACTOR_GUARDIAN = "guardian";
    string internal constant ACTOR_ALICE = "alice";
    string internal constant ACTOR_BOB = "bob";

    /*//////////////////////////////////////////////////////////////
                            TOKEN METADATA
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                          DEFAULT ROLE CONFIG
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant MANAGER_ROLE = 1;
    uint8 internal constant STRATEGIST_ROLE = 2;
    uint8 internal constant MANAGER_INTERNAL_ROLE = 3;
    uint8 internal constant MANAGER_ADMIN_ROLE = 4;
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_CALLER_ROLE = 9;

    /*//////////////////////////////////////////////////////////////
                         DEFAULT VAULT PARAMETERS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_SENIOR_RATE_PER_SECOND_WAD = 0;
    uint256 internal constant DEFAULT_MAX_SENIOR_RATIO_BPS = 8_000;
    uint256 internal constant DEFAULT_MAX_RATE_AGE = 0;
    uint256 internal constant UPDATED_MAX_RATE_AGE = 1_800;
    uint256 internal constant UPDATED_MAX_SENIOR_RATIO_BPS = 9_000;
    uint256 internal constant INVALID_BPS = 10_001;

    uint256 internal constant ACCOUNTANT_PAR_RATE = TestConstants.ONE_WAD;
    uint256 internal constant ACCOUNTANT_BULL_RATE = 11e17;
    uint256 internal constant ACCOUNTANT_BEAR_RATE = 7e17;
    uint256 internal constant ACCOUNTANT_PEGGED_SHARE_PRICE = TestConstants.ONE_USDC;
    uint256 internal constant ACCOUNTANT_UPPER_BOUND_BPS = 11_000;
    uint256 internal constant ACCOUNTANT_LOWER_BOUND_BPS = 9_000;
    uint24 internal constant ACCOUNTANT_MIN_UPDATE_DELAY_SECONDS = 0;
    uint16 internal constant ACCOUNTANT_PLATFORM_FEE = 0;
    uint16 internal constant ACCOUNTANT_PERFORMANCE_FEE = 0;
    uint16 internal constant TELLER_CREDIT_LIMIT = 0;

    /*//////////////////////////////////////////////////////////////
                        DEFAULT TEST AMOUNTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_INITIAL_BALANCE = 1_000_000 * TestConstants.ONE_USDC;
    uint256 internal constant DEFAULT_JUNIOR_DEPOSIT = 200 * TestConstants.ONE_USDC;
    uint256 internal constant DEFAULT_SENIOR_DEPOSIT = 800 * TestConstants.ONE_USDC;
    uint256 internal constant DEFAULT_TOTAL_BORING_SHARES =
        (DEFAULT_JUNIOR_DEPOSIT + DEFAULT_SENIOR_DEPOSIT) * TestConstants.ASSET_TO_SHARE_SCALE;
    uint256 internal constant DEFAULT_JUNIOR_REMAINING_SHARES = 200 * TestConstants.ONE_SHARE;

    uint256 internal constant SMALL_DEPOSIT = 10 * TestConstants.ONE_USDC;
    uint256 internal constant SMALL_JUNIOR_DEPOSIT = 50 * TestConstants.ONE_USDC;
    uint256 internal constant SMALL_SHARES = 50 * TestConstants.ONE_USDC;
    uint256 internal constant ONE_UNIT = TestConstants.ONE_USDC;

    uint256 internal constant TOKEN_MINT_AMOUNT = 10 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_TRANSFER_AMOUNT = 3 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_APPROVE_AMOUNT = 2 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_BURN_AMOUNT = 4 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_BURN_APPROVAL = 6 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_POST_BURN_SUPPLY = 6 * TestConstants.ONE_USDC;
    uint256 internal constant TOKEN_POST_BURN_ALLOWANCE = 2 * TestConstants.ONE_USDC;

    uint256 internal constant OPENFI_SUPPLY_AMOUNT = 1_250 * TestConstants.ONE_USDC;
    uint256 internal constant OPENFI_WITHDRAW_AMOUNT = 250 * TestConstants.ONE_USDC;
    uint256 internal constant OPENFI_FORK_ROUNDTRIP = 1_000 * TestConstants.ONE_USDC;
    uint256 internal constant MANAGER_TEST_OPENFI_AMOUNT = 300 * TestConstants.ONE_USDC;
    uint256 internal constant MANAGER_TEST_ASSETO_AMOUNT = 200 * TestConstants.ONE_USDC;
    uint256 internal constant FORK_BALANCE_DUST_TOLERANCE = 1;

    uint256 internal constant ACCRUAL_TEST_RATE = 1e14;
    uint256 internal constant ACCRUAL_WARP_SECONDS = 3_600;
    uint256 internal constant PRICE_ASSERT_DELTA = 2;
    uint256 internal constant SMALL_SENIOR_MULTIPLIER = 10;
    uint256 internal constant UNDERWATER_SENIOR_ASSETS = 700 * TestConstants.ONE_USDC;
    uint256 internal constant ROLE_TEST_RATE = 1;
    uint256 internal constant HALF_POSITION = 2;
    uint256 internal constant SENIOR_UPSIDE_DIVISOR = 8;
    uint256 internal constant SENIOR_CAP_NUMERATOR = 4;
    uint256 internal constant SENIOR_CAP_DENOMINATOR = 5;

    /*//////////////////////////////////////////////////////////////
                        RATE MODEL DEFAULTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant FIXED_RATE_INITIAL = 100;
    uint256 internal constant FIXED_RATE_UPDATED = 250;
    uint256 internal constant CAP_MODEL_CAP = 1_000;
    uint256 internal constant CAP_MODEL_REF_LOW = 900;
    uint256 internal constant CAP_MODEL_REF_HIGH = 2_000;
    uint256 internal constant CAP_MODEL_SAFETY_DEFAULT = 8e17;
    uint256 internal constant CAP_MODEL_SAFETY_UPDATED = 5e17;
    uint256 internal constant CAP_MODEL_EXPECTED_LOW = 720;

    /*//////////////////////////////////////////////////////////////
                       INVARIANT AND FUZZ DEFAULTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant INVARIANT_MIN_BOUND = 1;
    uint256 internal constant INVARIANT_RATE_MIN = 6e17;
    uint256 internal constant INVARIANT_RATE_MAX = 12e17;
    uint256 internal constant INVARIANT_JUNIOR_BOOTSTRAP = 200_000 * TestConstants.ONE_USDC;
    uint256 internal constant INVARIANT_SENIOR_BOOTSTRAP = 400_000 * TestConstants.ONE_USDC;

    uint256 internal constant FUZZ_MIN_ASSETS = 100 * TestConstants.ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_A = 300_000 * TestConstants.ONE_USDC;
    uint256 internal constant FUZZ_MAX_JUNIOR_B = 500_000 * TestConstants.ONE_USDC;
    uint256 internal constant FUZZ_MAX_SENIOR = 800_000 * TestConstants.ONE_USDC;

    /*//////////////////////////////////////////////////////////////
                           SAMPLE FIXTURES
    //////////////////////////////////////////////////////////////*/

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

    bytes32 internal constant SAMPLE_PARAMS_HASH = keccak256("sample");
    bytes32 internal constant SAMPLE_PARAMS_HASH_2 = keccak256("sample-2");
}
