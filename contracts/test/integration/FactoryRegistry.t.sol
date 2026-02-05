// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../../src/tranche/TrancheRegistry.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";

contract FactoryRegistryIntegrationTest is Test {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;

    address internal owner;
    address internal operator;
    address internal guardian;
    address internal manager;
    address internal outsider;

    MockERC20 internal asset;
    BoringVault internal boringVault;
    AccountantWithRateProviders internal accountant;
    TellerWithMultiAssetSupport internal teller;
    RolesAuthority internal rolesAuthority;
    WETH internal weth;

    TrancheController internal controllerImpl;
    TrancheToken internal tokenImpl;
    TrancheRegistry internal registry;
    TrancheFactory internal factory;

    function setUp() public {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");
        manager = makeAddr("manager");
        outsider = makeAddr("outsider");

        asset = new MockERC20("USDC", "USDC", 6);
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), address(this), 1e6, address(asset), 11_000, 9_000, 0, 0, 0
        );
        weth = new WETH();
        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(weth));
        teller.updateAssetData(ERC20(address(asset)), true, true, 0);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        controllerImpl = new TrancheController();
        tokenImpl = new TrancheToken();

        registry = new TrancheRegistry(owner, address(0));
        factory = new TrancheFactory(owner, address(controllerImpl), address(tokenImpl), address(registry));

        vm.prank(owner);
        registry.setFactory(address(factory));
    }

    function test_ownerCanCreateProductAndRegistryStoresWiring() public {
        TrancheFactory.ProductConfig memory config = TrancheFactory.ProductConfig({
            paramsHash: keccak256("usdc-lending-s1"),
            asset: address(asset),
            vault: address(boringVault),
            teller: address(teller),
            accountant: address(accountant),
            manager: manager,
            operator: operator,
            guardian: guardian,
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
        uint256 productId = factory.createProduct(config);
        assertEq(productId, 0);
        assertEq(registry.productCount(), 1);

        TrancheRegistry.ProductInfo memory info = registry.products(productId);
        assertEq(info.asset, address(asset));
        assertEq(info.vault, address(boringVault));
        assertEq(info.teller, address(teller));
        assertEq(info.accountant, address(accountant));
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
        assertEq(controller.maxSeniorRatioBps(), 8_000);
    }

    function test_createProduct_revertsForNonOwner() public {
        TrancheFactory.ProductConfig memory config = TrancheFactory.ProductConfig({
            paramsHash: bytes32(0),
            asset: address(asset),
            vault: address(boringVault),
            teller: address(teller),
            accountant: address(accountant),
            manager: manager,
            operator: operator,
            guardian: guardian,
            tokenDecimals: 6,
            seniorRatePerSecondWad: 0,
            rateModel: address(0),
            maxSeniorRatioBps: 8_000,
            seniorName: "Pontus Vault Senior USDC S1",
            seniorSymbol: "pvS-USDC",
            juniorName: "Pontus Vault Junior USDC S1",
            juniorSymbol: "pvJ-USDC"
        });

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        factory.createProduct(config);
    }
}
