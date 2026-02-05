// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";

contract TrancheRegistryTest is Test {
    TrancheRegistry internal registry;

    address internal owner;
    address internal factory;
    address internal outsider;

    function setUp() public {
        owner = makeAddr("owner");
        factory = makeAddr("factory");
        outsider = makeAddr("outsider");
        registry = new TrancheRegistry(owner, factory);
    }

    function test_setFactory_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        registry.setFactory(makeAddr("newFactory"));
    }

    function test_setFactory_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TrancheRegistry.ZeroAddress.selector);
        registry.setFactory(address(0));
    }

    function test_setFactory_updatesFactory() public {
        address newFactory = makeAddr("newFactory");
        vm.prank(owner);
        registry.setFactory(newFactory);
        assertEq(registry.factory(), newFactory);
    }

    function test_registerTrancheVault_revertsForNonFactory() public {
        TrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();
        vm.prank(outsider);
        vm.expectRevert(TrancheRegistry.NotFactory.selector);
        registry.registerTrancheVault(info);
    }

    function test_registerTrancheVault_storesVaultForFactory() public {
        TrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();
        vm.prank(factory);
        uint256 vaultId = registry.registerTrancheVault(info);
        assertEq(vaultId, 0);
        assertEq(registry.trancheVaultCount(), 1);

        TrancheRegistry.TrancheVaultInfo memory stored = registry.trancheVaults(0);
        assertEq(stored.controller, info.controller);
        assertEq(stored.seniorToken, info.seniorToken);
        assertEq(stored.juniorToken, info.juniorToken);
        assertEq(stored.vault, info.vault);
        assertEq(stored.teller, info.teller);
        assertEq(stored.accountant, info.accountant);
        assertEq(stored.manager, info.manager);
        assertEq(stored.asset, info.asset);
        assertEq(stored.paramsHash, info.paramsHash);
    }

    function test_getTrancheVaults_paginates() public {
        TrancheRegistry.TrancheVaultInfo memory info0 = _sampleTrancheVault();
        TrancheRegistry.TrancheVaultInfo memory info1 = _sampleTrancheVault();
        info1.controller = address(0x2001);
        info1.paramsHash = keccak256("sample-2");

        vm.startPrank(factory);
        registry.registerTrancheVault(info0);
        registry.registerTrancheVault(info1);
        vm.stopPrank();

        TrancheRegistry.TrancheVaultInfo[] memory page = registry.getTrancheVaults(1, 10);
        assertEq(page.length, 1);
        assertEq(page[0].controller, info1.controller);

        TrancheRegistry.TrancheVaultInfo[] memory emptyPage = registry.getTrancheVaults(3, 10);
        assertEq(emptyPage.length, 0);
    }

    function _sampleTrancheVault() internal pure returns (TrancheRegistry.TrancheVaultInfo memory) {
        return TrancheRegistry.TrancheVaultInfo({
            controller: address(0x1001),
            seniorToken: address(0x1002),
            juniorToken: address(0x1003),
            vault: address(0x1004),
            teller: address(0x1005),
            accountant: address(0x1006),
            manager: address(0x1007),
            asset: address(0x1008),
            paramsHash: keccak256("sample")
        });
    }
}
