// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ManagerWithMerkleVerification} from "../../lib/boring-vault/src/base/Roles/ManagerWithMerkleVerification.sol";

import {AssetoDecoderAndSanitizer} from "../../src/decoders/AssetoDecoderAndSanitizer.sol";
import {OpenFiDecoderAndSanitizer} from "../../src/decoders/OpenFiDecoderAndSanitizer.sol";
import {AssetoCallBuilder} from "../../src/libraries/AssetoCallBuilder.sol";
import {ManagerMerkleLib} from "../../src/libraries/ManagerMerkleLib.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";

import {MockAssetoProduct} from "../mocks/MockAssetoProduct.sol";
import {MockManagedOpenFiPool} from "../mocks/MockManagedOpenFiPool.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {IntegrationTest} from "./IntegrationTest.sol";

/// @title Manager Merkle Integration Test
/// @author Kevin Lin (@kevinsslin)
/// @notice Validates end-to-end manager flow (root/proof + decoder) across OpenFi and Asseto adapters.
contract ManagerMerkleIntegrationTest is IntegrationTest {
    bytes4 internal constant BORING_VAULT_MANAGE_SINGLE_SELECTOR = bytes4(keccak256("manage(address,bytes,uint256)"));
    bytes4 internal constant BORING_VAULT_MANAGE_BATCH_SELECTOR =
        bytes4(keccak256("manage(address[],bytes[],uint256[])"));

    address internal strategist;
    address internal managerAdmin;

    ManagerWithMerkleVerification internal manager;
    OpenFiDecoderAndSanitizer internal openFiDecoder;
    AssetoDecoderAndSanitizer internal assetoDecoder;
    MockManagedOpenFiPool internal openFiPool;
    MockAssetoProduct internal assetoProduct;

    function setUp() public override {
        IntegrationTest.setUp();

        strategist = makeAddr("strategist");
        managerAdmin = makeAddr("managerAdmin");

        _wireControllerToBoringVault(TestConstants.ZERO_ADDRESS);
        _seedBalances(TestDefaults.DEFAULT_INITIAL_BALANCE);
        _depositJunior(bob, TestDefaults.DEFAULT_JUNIOR_DEPOSIT);
        _depositSenior(alice, TestDefaults.DEFAULT_SENIOR_DEPOSIT);

        openFiPool = new MockManagedOpenFiPool(IERC20(address(asset)));
        assetoProduct = new MockAssetoProduct(IERC20(address(asset)));
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), TestConstants.ZERO_ADDRESS);
        openFiDecoder = new OpenFiDecoderAndSanitizer(address(boringVault));
        assetoDecoder = new AssetoDecoderAndSanitizer(address(boringVault));
        manager.setAuthority(rolesAuthority);

        _configureManagerRoles();
    }

    function test_manage_vault_with_merkle_verification_runs_open_fi_and_asseto_flows() public {
        uint256 openFiAmount = TestDefaults.MANAGER_TEST_OPENFI_AMOUNT;
        uint256 assetoAmount = TestDefaults.MANAGER_TEST_ASSETO_AMOUNT;
        uint256 vaultAssetsBefore = IERC20(address(asset)).balanceOf(address(boringVault));

        uint256 callCount = 6;
        address[] memory targets = new address[](callCount);
        bytes[] memory targetData = new bytes[](callCount);
        uint256[] memory values = new uint256[](callCount);
        address[] memory decoders = new address[](callCount);
        bytes32[] memory leafHashes = new bytes32[](callCount);

        targets[0] = address(asset);
        targetData[0] = abi.encodeWithSelector(IERC20.approve.selector, address(openFiPool), openFiAmount);
        leafHashes[0] = ManagerMerkleLib.hashLeafFromCallData(
            address(openFiDecoder), targets[0], 0, targetData[0], abi.encodePacked(address(openFiPool))
        );

        targets[1] = address(openFiPool);
        targetData[1] = OpenFiCallBuilder.supplyCalldata(address(asset), openFiAmount, address(boringVault));
        leafHashes[1] = ManagerMerkleLib.hashLeafFromCallData(
            address(openFiDecoder), targets[1], 0, targetData[1], abi.encodePacked(address(asset), address(boringVault))
        );

        targets[2] = address(openFiPool);
        targetData[2] = OpenFiCallBuilder.withdrawCalldata(address(asset), openFiAmount, address(boringVault));
        leafHashes[2] = ManagerMerkleLib.hashLeafFromCallData(
            address(openFiDecoder), targets[2], 0, targetData[2], abi.encodePacked(address(asset), address(boringVault))
        );

        targets[3] = address(asset);
        targetData[3] = abi.encodeWithSelector(IERC20.approve.selector, address(assetoProduct), assetoAmount);
        leafHashes[3] = ManagerMerkleLib.hashLeafFromCallData(
            address(assetoDecoder), targets[3], 0, targetData[3], abi.encodePacked(address(assetoProduct))
        );

        targets[4] = address(assetoProduct);
        targetData[4] = AssetoCallBuilder.subscribeCalldata(address(boringVault), assetoAmount);
        leafHashes[4] = ManagerMerkleLib.hashLeafFromCallData(
            address(assetoDecoder), targets[4], 0, targetData[4], abi.encodePacked(address(boringVault))
        );

        targets[5] = address(assetoProduct);
        targetData[5] = AssetoCallBuilder.redemptionCalldata(address(boringVault), assetoAmount);
        leafHashes[5] = ManagerMerkleLib.hashLeafFromCallData(
            address(assetoDecoder), targets[5], 0, targetData[5], abi.encodePacked(address(boringVault))
        );

        decoders[0] = address(openFiDecoder);
        decoders[1] = address(openFiDecoder);
        decoders[2] = address(openFiDecoder);
        decoders[3] = address(assetoDecoder);
        decoders[4] = address(assetoDecoder);
        decoders[5] = address(assetoDecoder);

        bytes32[][] memory proofs = new bytes32[][](callCount);
        bytes32 rootHash = ManagerMerkleLib.root(leafHashes);
        for (uint256 i; i < callCount; ++i) {
            proofs[i] = ManagerMerkleLib.proof(leafHashes, i);
        }

        vm.prank(managerAdmin);
        manager.setManageRoot(strategist, rootHash);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);

        assertEq(openFiPool.totalSupplied(), 0);
        assertEq(openFiPool.suppliedBalance(address(boringVault)), 0);
        assertEq(assetoProduct.totalSubscribed(), 0);
        assertEq(assetoProduct.balanceOf(address(boringVault)), 0);
        assertEq(IERC20(address(asset)).balanceOf(address(boringVault)), vaultAssetsBefore);
    }

    function _configureManagerRoles() internal {
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_ROLE, address(boringVault), BORING_VAULT_MANAGE_SINGLE_SELECTOR, true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_ROLE, address(boringVault), BORING_VAULT_MANAGE_BATCH_SELECTOR, true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_ADMIN_ROLE,
            address(manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.MANAGER_ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector, true
        );

        rolesAuthority.setUserRole(address(manager), TestDefaults.MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), TestDefaults.MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(strategist, TestDefaults.STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(managerAdmin, TestDefaults.MANAGER_ADMIN_ROLE, true);
    }
}
