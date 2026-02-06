// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";
import {TrancheRegistryV2} from "../mocks/TrancheRegistryV2.sol";

contract TrancheRegistryTest is Test {
    TrancheRegistry internal registry;

    address internal owner;
    address internal factory;
    address internal outsider;

    function setUp() public {
        owner = makeAddr("owner");
        factory = makeAddr("factory");
        outsider = makeAddr("outsider");

        TrancheRegistry registryImpl = new TrancheRegistry();
        registry = TrancheRegistry(
            address(
                new ERC1967Proxy(address(registryImpl), abi.encodeCall(TrancheRegistry.initialize, (owner, factory)))
            )
        );
    }

    function test_initialize_revertsWhenCalledTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(owner, factory);
    }

    function test_setFactory_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
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

    function test_upgradeToAndCall_revertsForNonOwner() public {
        TrancheRegistryV2 newImpl = new TrancheRegistryV2();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        registry.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgradeToAndCall_preservesState() public {
        TrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();

        vm.prank(factory);
        registry.registerTrancheVault(info);

        TrancheRegistryV2 newImpl = new TrancheRegistryV2();
        vm.prank(owner);
        registry.upgradeToAndCall(address(newImpl), "");

        assertEq(registry.factory(), factory);
        assertEq(registry.trancheVaultCount(), 1);
        assertEq(TrancheRegistryV2(address(registry)).version(), 2);
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
