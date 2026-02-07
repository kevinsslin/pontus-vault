// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ITrancheRegistry} from "../../src/interfaces/ITrancheRegistry.sol";
import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";
import {BaseTest} from "../BaseTest.sol";
import {TrancheRegistryV2} from "../mocks/TrancheRegistryV2.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

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
        vm.expectRevert(ITrancheRegistry.ZeroAddress.selector);
        registry.setFactory(TestConstants.ZERO_ADDRESS);
    }

    function test_setFactory_updatesFactory() public {
        address newFactory = makeAddr("newFactory");
        vm.prank(owner);
        registry.setFactory(newFactory);
        assertEq(registry.factory(), newFactory);
    }

    function test_registerTrancheVault_revertsForNonFactory() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();
        vm.prank(outsider);
        vm.expectRevert(ITrancheRegistry.NotFactory.selector);
        registry.registerTrancheVault(info);
    }

    function test_registerTrancheVault_storesVaultForFactory() public {
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

    function test_registerTrancheVault_revertsWhenParamsHashAlreadyExists() public {
        ITrancheRegistry.TrancheVaultInfo memory info = _sampleTrancheVault();

        vm.startPrank(factory);
        registry.registerTrancheVault(info);
        vm.expectRevert(
            abi.encodeWithSelector(ITrancheRegistry.TrancheVaultAlreadyRegistered.selector, info.paramsHash)
        );
        registry.registerTrancheVault(info);
        vm.stopPrank();
    }

    function test_trancheVaultByParamsHash_revertsWhenUnknown() public {
        vm.expectRevert(
            abi.encodeWithSelector(ITrancheRegistry.TrancheVaultNotFound.selector, TestDefaults.SAMPLE_PARAMS_HASH_2)
        );
        registry.trancheVaultByParamsHash(TestDefaults.SAMPLE_PARAMS_HASH_2);
    }

    function test_upgradeToAndCall_revertsForNonOwner() public {
        TrancheRegistryV2 newImpl = new TrancheRegistryV2();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        registry.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgradeToAndCall_preservesState() public {
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
            controller: TestConstants.SAMPLE_CONTROLLER,
            seniorToken: TestConstants.SAMPLE_SENIOR_TOKEN,
            juniorToken: TestConstants.SAMPLE_JUNIOR_TOKEN,
            vault: TestConstants.SAMPLE_VAULT,
            teller: TestConstants.SAMPLE_TELLER,
            accountant: TestConstants.SAMPLE_ACCOUNTANT,
            manager: TestConstants.SAMPLE_MANAGER,
            asset: TestConstants.SAMPLE_ASSET,
            paramsHash: TestDefaults.SAMPLE_PARAMS_HASH
        });
    }
}
