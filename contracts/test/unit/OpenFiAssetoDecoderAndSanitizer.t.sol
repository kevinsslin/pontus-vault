// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {OpenFiAssetoDecoderAndSanitizer} from "../../src/decoders/OpenFiAssetoDecoderAndSanitizer.sol";
import {BaseTest} from "../BaseTest.sol";

contract OpenFiAssetoDecoderAndSanitizerTest is BaseTest {
    OpenFiAssetoDecoderAndSanitizer internal decoder;

    function setUp() public override {
        BaseTest.setUp();
        decoder = new OpenFiAssetoDecoderAndSanitizer(address(this));
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

    function test_subscribe_returnsPackedBeneficiary() public {
        address beneficiary = makeAddr("beneficiary");
        bytes memory packed = decoder.subscribe(beneficiary, 777);
        assertEq(packed, abi.encodePacked(beneficiary));
    }

    function test_redemption_returnsPackedBeneficiary() public {
        address beneficiary = makeAddr("beneficiary");
        bytes memory packed = decoder.redemption(beneficiary, 888);
        assertEq(packed, abi.encodePacked(beneficiary));
    }

    function test_approve_fromBaseDecoder_returnsPackedSpender() public {
        address spender = makeAddr("spender");
        bytes memory packed = decoder.approve(spender, 100);
        assertEq(packed, abi.encodePacked(spender));
    }
}
