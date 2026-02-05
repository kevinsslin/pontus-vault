// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";

contract TrancheFactoryTest is Test {
    address internal owner;
    address internal outsider;

    TrancheController internal controllerImpl;
    TrancheToken internal tokenImpl;

    function setUp() public {
        owner = makeAddr("owner");
        outsider = makeAddr("outsider");
        controllerImpl = new TrancheController();
        tokenImpl = new TrancheToken();
    }

    function test_constructor_revertsWhenControllerImplIsZero() public {
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        new TrancheFactory(owner, address(0), address(tokenImpl), address(1));
    }

    function test_constructor_revertsWhenTokenImplIsZero() public {
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        new TrancheFactory(owner, address(controllerImpl), address(0), address(1));
    }

    function test_setRegistry_revertsForNonOwner() public {
        TrancheFactory factory = new TrancheFactory(owner, address(controllerImpl), address(tokenImpl), address(1));
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        factory.setRegistry(address(2));
    }

    function test_setRegistry_revertsOnZeroAddress() public {
        TrancheFactory factory = new TrancheFactory(owner, address(controllerImpl), address(tokenImpl), address(1));
        vm.prank(owner);
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        factory.setRegistry(address(0));
    }

    function test_createTrancheVault_revertsWhenRegistryIsUnset() public {
        TrancheFactory factory = new TrancheFactory(owner, address(controllerImpl), address(tokenImpl), address(0));

        TrancheFactory.TrancheVaultConfig memory config = TrancheFactory.TrancheVaultConfig({
            paramsHash: bytes32(0),
            asset: address(1),
            vault: address(2),
            teller: address(3),
            accountant: address(4),
            manager: address(5),
            operator: address(6),
            guardian: address(7),
            tokenDecimals: 6,
            seniorRatePerSecondWad: 0,
            rateModel: address(0),
            maxSeniorRatioBps: 8_000,
            seniorName: "Pontus Vault Senior USDC S1",
            seniorSymbol: "pvS-USDC",
            juniorName: "Pontus Vault Junior USDC S1",
            juniorSymbol: "pvJ-USDC"
        });

        vm.prank(owner);
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        factory.createTrancheVault(config);
    }
}
