// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {IntegrationTest} from "./IntegrationTest.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract FactoryRegistryIntegrationTest is IntegrationTest {
    address internal owner;
    address internal manager;
    address internal outsider;

    TrancheController internal controllerImpl;
    TrancheToken internal tokenImpl;
    TrancheRegistry internal registry;
    TrancheFactory internal factory;

    function setUp() public override {
        super.setUp();

        owner = makeAddr("owner");
        manager = makeAddr("manager");
        outsider = makeAddr("outsider");

        controllerImpl = new TrancheController();
        tokenImpl = new TrancheToken();

        TrancheRegistry registryImpl = new TrancheRegistry();
        registry = TrancheRegistry(
            address(
                new ERC1967Proxy(address(registryImpl), abi.encodeCall(TrancheRegistry.initialize, (owner, address(0))))
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

    function test_ownerCanCreateVaultAndRegistryStoresWiring() public {
        TrancheFactory.TrancheVaultConfig memory config = _defaultConfig(TestDefaults.DEFAULT_PARAMS_HASH);

        vm.prank(owner);
        uint256 vaultId = factory.createTrancheVault(config);
        assertEq(vaultId, 0);
        assertEq(registry.trancheVaultCount(), 1);

        TrancheRegistry.TrancheVaultInfo memory info = registry.trancheVaults(vaultId);
        assertEq(info.asset, address(asset));
        assertEq(info.vault, address(boringVault));
        assertEq(info.teller, address(boringVaultTeller));
        assertEq(info.accountant, address(boringVaultAccountant));
        assertEq(info.manager, manager);
        assertEq(info.paramsHash, config.paramsHash);
        assertTrue(info.controller != address(0));
        assertTrue(info.seniorToken != address(0));
        assertTrue(info.juniorToken != address(0));
        assertTrue(info.seniorToken != info.juniorToken);

        TrancheController controller = TrancheController(info.controller);
        assertEq(address(controller.asset()), address(asset));
        assertEq(address(controller.seniorToken()), info.seniorToken);
        assertEq(address(controller.juniorToken()), info.juniorToken);
        assertEq(controller.maxSeniorRatioBps(), TestConstants.DEFAULT_MAX_SENIOR_RATIO_BPS);
    }

    function test_createTrancheVault_revertsForNonOwner() public {
        TrancheFactory.TrancheVaultConfig memory config = _defaultConfig(bytes32(0));

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        factory.createTrancheVault(config);
    }

    function _defaultConfig(bytes32 paramsHash) internal view returns (TrancheFactory.TrancheVaultConfig memory) {
        return TrancheFactory.TrancheVaultConfig({
            paramsHash: paramsHash,
            asset: address(asset),
            vault: address(boringVault),
            teller: address(boringVaultTeller),
            accountant: address(boringVaultAccountant),
            manager: manager,
            operator: operator,
            guardian: guardian,
            tokenDecimals: TestConstants.USDC_DECIMALS,
            seniorRatePerSecondWad: 0,
            rateModel: address(0),
            maxSeniorRatioBps: TestConstants.DEFAULT_MAX_SENIOR_RATIO_BPS,
            seniorName: TestDefaults.SENIOR_TOKEN_NAME,
            seniorSymbol: TestDefaults.SENIOR_TOKEN_SYMBOL,
            juniorName: TestDefaults.JUNIOR_TOKEN_NAME,
            juniorSymbol: TestDefaults.JUNIOR_TOKEN_SYMBOL
        });
    }
}
