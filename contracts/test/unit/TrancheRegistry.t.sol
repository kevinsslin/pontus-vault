// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ITrancheRegistry} from "../../src/interfaces/tranche/ITrancheRegistry.sol";
import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";

import {TrancheRegistryV2} from "../mocks/TrancheRegistryV2.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseTest} from "../BaseTest.sol";

contract TrancheRegistryTest is BaseTest {
    TrancheRegistry internal registry;

    address internal owner;
    address internal factory;
    address internal outsider;

    function setUp() public override {
        BaseTest.setUp();
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

    function test_initialize_reverts_when_called_twice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(owner, factory);
    }

    function test_set_factory_reverts_for_non_owner() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        registry.setFactory(makeAddr("newFactory"));
    }

    function test_set_factory_reverts_on_zero_address() public {
        vm.prank(owner);
        vm.expectRevert(ITrancheRegistry.ZeroAddress.selector);
        registry.setFactory(TestConstants.ZERO_ADDRESS);
    }

    function test_set_factory_updates_factory() public {
        address newFactory = makeAddr("newFactory");
        vm.prank(owner);
        registry.setFactory(newFactory);
        assertEq(registry.factory(), newFactory);
    }

    function test_register_tranche_vault_reverts_for_non_factory() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();
        vm.prank(outsider);
        vm.expectRevert(ITrancheRegistry.NotFactory.selector);
        registry.registerTrancheVault(info);
    }

    function test_register_tranche_vault_stores_vault_for_factory() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();
        vm.prank(factory);
        bytes32 paramsHash = registry.registerTrancheVault(info);
        assertEq(paramsHash, info.paramsHash);
        assertTrue(registry.trancheVaultExists(paramsHash));

        ITrancheRegistry.TrancheVaultInfo memory stored = registry.trancheVaultByParamsHash(paramsHash);
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

    function test_register_tranche_vault_reverts_when_params_hash_already_exists() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();

        vm.startPrank(factory);
        registry.registerTrancheVault(info);
        vm.expectRevert(
            abi.encodeWithSelector(ITrancheRegistry.TrancheVaultAlreadyRegistered.selector, info.paramsHash)
        );
        registry.registerTrancheVault(info);
        vm.stopPrank();
    }

    function test_tranche_vault_by_params_hash_reverts_when_unknown() public {
        vm.expectRevert(
            abi.encodeWithSelector(ITrancheRegistry.TrancheVaultNotFound.selector, TestDefaults.SAMPLE_PARAMS_HASH_2)
        );
        registry.trancheVaultByParamsHash(TestDefaults.SAMPLE_PARAMS_HASH_2);
    }

    function test_upgrade_to_and_call_reverts_for_non_owner() public {
        TrancheRegistryV2 newImpl = new TrancheRegistryV2();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        registry.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_to_and_call_preserves_state() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();

        vm.prank(factory);
        registry.registerTrancheVault(info);

        TrancheRegistryV2 newImpl = new TrancheRegistryV2();
        vm.prank(owner);
        registry.upgradeToAndCall(address(newImpl), "");

        assertEq(registry.factory(), factory);
        assertTrue(registry.trancheVaultExists(info.paramsHash));
        ITrancheRegistry.TrancheVaultInfo memory stored = registry.trancheVaultByParamsHash(info.paramsHash);
        assertEq(stored.controller, info.controller);
        assertEq(TrancheRegistryV2(address(registry)).version(), 2);
    }

    function _sampleTrancheVault() internal pure returns (ITrancheRegistry.TrancheVaultInfo memory) {
        return ITrancheRegistry.TrancheVaultInfo({
            controller: TestDefaults.SAMPLE_CONTROLLER,
            seniorToken: TestDefaults.SAMPLE_SENIOR_TOKEN,
            juniorToken: TestDefaults.SAMPLE_JUNIOR_TOKEN,
            vault: TestDefaults.SAMPLE_VAULT,
            teller: TestDefaults.SAMPLE_TELLER,
            accountant: TestDefaults.SAMPLE_ACCOUNTANT,
            manager: TestDefaults.SAMPLE_MANAGER,
            asset: TestDefaults.SAMPLE_ASSET,
            paramsHash: TestDefaults.SAMPLE_PARAMS_HASH
        });
    }
}
