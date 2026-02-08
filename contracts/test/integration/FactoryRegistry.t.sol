// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {ITrancheFactory} from "../../src/interfaces/tranche/ITrancheFactory.sol";
import {ITrancheRegistry} from "../../src/interfaces/tranche/ITrancheRegistry.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {IntegrationTest} from "./IntegrationTest.sol";

contract FactoryRegistryIntegrationTest is IntegrationTest {
    address internal owner;
    address internal manager;
    address internal outsider;

    TrancheController internal controllerImpl;
    TrancheToken internal tokenImpl;
    TrancheRegistry internal registry;
    TrancheFactory internal factory;

    function setUp() public override {
        IntegrationTest.setUp();

        owner = makeAddr("owner");
        manager = makeAddr("manager");
        outsider = makeAddr("outsider");

        controllerImpl = new TrancheController();
        tokenImpl = new TrancheToken();

        TrancheRegistry registryImpl = new TrancheRegistry();
        registry = TrancheRegistry(
            address(
                new ERC1967Proxy(
                    address(registryImpl),
                    abi.encodeCall(TrancheRegistry.initialize, (owner, TestConstants.ZERO_ADDRESS))
                )
            )
        );

        TrancheFactory factoryImpl = new TrancheFactory();
        factory = TrancheFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImpl),
                    abi.encodeCall(
                        TrancheFactory.initialize,
                        (owner, address(controllerImpl), address(tokenImpl), address(registry))
                    )
                )
            )
        );

        vm.prank(owner);
        registry.setFactory(address(factory));
    }

    function test_owner_can_create_vault_and_registry_stores_wiring() public {
        ITrancheFactory.TrancheVaultConfig memory config = _defaultConfig();
        bytes32 expectedParamsHash = factory.computeParamsHash(config);

        vm.prank(owner);
        bytes32 paramsHash = factory.createTrancheVault(config);
        assertEq(paramsHash, expectedParamsHash);
        assertTrue(registry.trancheVaultExists(paramsHash));

        ITrancheRegistry.TrancheVaultInfo memory info = registry.trancheVaultByParamsHash(paramsHash);
        assertEq(info.asset, address(asset));
        assertEq(info.vault, address(boringVault));
        assertEq(info.teller, address(boringVaultTeller));
        assertEq(info.accountant, address(boringVaultAccountant));
        assertEq(info.manager, manager);
        assertEq(info.paramsHash, expectedParamsHash);
        assertTrue(info.controller != address(0));
        assertTrue(info.seniorToken != address(0));
        assertTrue(info.juniorToken != address(0));
        assertTrue(info.seniorToken != info.juniorToken);

        TrancheController controller = TrancheController(info.controller);
        assertEq(address(controller.asset()), address(asset));
        assertEq(address(controller.seniorToken()), info.seniorToken);
        assertEq(address(controller.juniorToken()), info.juniorToken);
        assertEq(controller.maxSeniorRatioBps(), TestDefaults.DEFAULT_MAX_SENIOR_RATIO_BPS);
        assertEq(controller.maxRateAge(), TestDefaults.DEFAULT_MAX_RATE_AGE);
    }

    function test_create_tranche_vault_reverts_for_non_owner() public {
        ITrancheFactory.TrancheVaultConfig memory config = _defaultConfig();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        factory.createTrancheVault(config);
    }

    function _defaultConfig() internal view returns (ITrancheFactory.TrancheVaultConfig memory) {
        return ITrancheFactory.TrancheVaultConfig({
            asset: address(asset),
            vault: address(boringVault),
            teller: address(boringVaultTeller),
            accountant: address(boringVaultAccountant),
            manager: manager,
            operator: operator,
            guardian: guardian,
            tokenDecimals: TestConstants.USDC_DECIMALS,
            seniorRatePerSecondWad: TestDefaults.DEFAULT_SENIOR_RATE_PER_SECOND_WAD,
            rateModel: TestConstants.ZERO_ADDRESS,
            maxSeniorRatioBps: TestDefaults.DEFAULT_MAX_SENIOR_RATIO_BPS,
            maxRateAge: TestDefaults.DEFAULT_MAX_RATE_AGE,
            seniorName: TestDefaults.SENIOR_TOKEN_NAME,
            seniorSymbol: TestDefaults.SENIOR_TOKEN_SYMBOL,
            juniorName: TestDefaults.JUNIOR_TOKEN_NAME,
            juniorSymbol: TestDefaults.JUNIOR_TOKEN_SYMBOL
        });
    }
}
