// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {OpenFiDecoderAndSanitizer} from "../../src/decoders/OpenFiDecoderAndSanitizer.sol";

import {BaseTest} from "../BaseTest.sol";

contract OpenFiDecoderAndSanitizerTest is BaseTest {
    OpenFiDecoderAndSanitizer internal decoder;

    function setUp() public override {
        BaseTest.setUp();
        decoder = new OpenFiDecoderAndSanitizer(address(this));
    }

    function test_supply_returnsPackedAssetAndOnBehalfOf() public {
        address supplyAsset = makeAddr("supplyAsset");
        address onBehalfOf = makeAddr("onBehalfOf");
        bytes memory packed = decoder.supply(supplyAsset, 123, onBehalfOf, 0);
        assertEq(packed, abi.encodePacked(supplyAsset, onBehalfOf));
    }

    function test_withdraw_returnsPackedAssetAndRecipient() public {
        address withdrawAsset = makeAddr("withdrawAsset");
        address recipient = makeAddr("recipient");
        bytes memory packed = decoder.withdraw(withdrawAsset, 321, recipient);
        assertEq(packed, abi.encodePacked(withdrawAsset, recipient));
    }

    function test_approve_fromBaseDecoder_returnsPackedSpender() public {
        address spender = makeAddr("spender");
        bytes memory packed = decoder.approve(spender, 100);
        assertEq(packed, abi.encodePacked(spender));
    }
}
