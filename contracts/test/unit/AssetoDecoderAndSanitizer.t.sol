// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AssetoDecoderAndSanitizer} from "../../src/decoders/AssetoDecoderAndSanitizer.sol";

import {BaseTest} from "../BaseTest.sol";

contract AssetoDecoderAndSanitizerTest is BaseTest {
    AssetoDecoderAndSanitizer internal decoder;

    function setUp() public override {
        BaseTest.setUp();
        decoder = new AssetoDecoderAndSanitizer(address(this));
    }

    function test_subscribe_returns_packed_beneficiary() public {
        address beneficiary = makeAddr("beneficiary");
        bytes memory packed = decoder.subscribe(beneficiary, 777);
        assertEq(packed, abi.encodePacked(beneficiary));
    }

    function test_redemption_returns_packed_beneficiary() public {
        address beneficiary = makeAddr("beneficiary");
        bytes memory packed = decoder.redemption(beneficiary, 888);
        assertEq(packed, abi.encodePacked(beneficiary));
    }

    function test_approve_from_base_decoder_returns_packed_spender() public {
        address spender = makeAddr("spender");
        bytes memory packed = decoder.approve(spender, 100);
        assertEq(packed, abi.encodePacked(spender));
    }
}
