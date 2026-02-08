// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Test Constants
/// @author Kevin Lin (@kevinsslin)
/// @notice Objective, environment or mathematical constants used by tests.
/// @dev Scenario-specific values belong in `TestDefaults`.
library TestConstants {
    uint256 internal constant JAN_1_2026 = 1_767_225_600; // 2026-01-01 00:00:00 UTC

    address internal constant ZERO_ADDRESS = address(0);

    uint8 internal constant USDC_DECIMALS = 6;
    uint8 internal constant BORING_VAULT_DECIMALS = 18;

    uint256 internal constant ONE_USDC = 1e6;
    uint256 internal constant ONE_SHARE = 1e18;
    uint256 internal constant ONE_WAD = 1e18;
    uint256 internal constant ASSET_TO_SHARE_SCALE = 1e12;

    uint256 internal constant BPS_SCALE = 10_000;

    uint16 internal constant OPENFI_REFERRAL_CODE = 0;
    address internal constant PHAROS_ATLANTIC_OPENFI_POOL = 0xEC86f142E7334d99EEEF2c43298413299D919B30;
    address internal constant PHAROS_ATLANTIC_ASSETO_CASH_PLUS = 0x56f4add11d723412D27A9e9433315401B351d6E3;
    address internal constant PHAROS_ATLANTIC_USDC = 0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8;
    address internal constant PHAROS_ATLANTIC_USDT = 0xE7E84B8B4f39C507499c40B4ac199B050e2882d5;
}
