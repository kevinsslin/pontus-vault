// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "../../lib/boring-vault/src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";

import {AssetoDecoderAndSanitizer} from "../../src/decoders/AssetoDecoderAndSanitizer.sol";
import {OpenFiDecoderAndSanitizer} from "../../src/decoders/OpenFiDecoderAndSanitizer.sol";
import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";
import {AssetoCallBuilder} from "../../src/libraries/AssetoCallBuilder.sol";
import {ManagerMerkleLib} from "../../src/libraries/ManagerMerkleLib.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseForkTest} from "./BaseForkTest.sol";

contract ManagerForkTest is BaseForkTest {
    bytes4 internal constant BORING_VAULT_MANAGE_SINGLE_SELECTOR = bytes4(keccak256("manage(address,bytes,uint256)"));
    bytes4 internal constant BORING_VAULT_MANAGE_BATCH_SELECTOR =
        bytes4(keccak256("manage(address[],bytes[],uint256[])"));

    struct ManagerContext {
        BoringVault vault;
        ManagerWithMerkleVerification manager;
        RolesAuthority rolesAuthority;
        address strategist;
        address managerAdmin;
    }

    struct ManagePlan {
        address[] targets;
        bytes[] targetData;
        uint256[] values;
        address[] decoders;
        bytes32[] leafHashes;
    }

    function test_open_fi_managed_roundtrip_on_pharos_fork() external {
        if (!_createForkOrSkip(TestDefaults.LOG_SKIP_MANAGER_FORK)) return;

        uint256 amount = vm.envOr("OPENFI_MANAGER_FORK_AMOUNT", TestConstants.OPENFI_FORK_ROUNDTRIP);
        address openFiPool = vm.envOr("OPENFI_MANAGER_POOL", TestConstants.PHAROS_ATLANTIC_OPENFI_POOL);
        _runOpenFiManagedRoundtrip(openFiPool, TestConstants.PHAROS_ATLANTIC_USDC, amount);
        _runOpenFiManagedRoundtrip(openFiPool, TestConstants.PHAROS_ATLANTIC_USDT, amount);
    }

    function test_asseto_managed_subscribe_redemption_on_pharos_fork() external {
        if (!vm.envOr("RUN_ASSETO_MANAGER_FORK", false)) {
            emit log(TestDefaults.LOG_SKIP_ASSETO_MANAGER_FORK);
            return;
        }

        if (!_createForkOrSkip(TestDefaults.LOG_SKIP_MANAGER_FORK)) return;

        address assetoProduct = vm.envOr("ASSETO_MANAGER_PRODUCT", TestConstants.PHAROS_ATLANTIC_ASSETO_CASH_PLUS);
        address asset = vm.envOr("ASSETO_MANAGER_ASSET", TestConstants.PHAROS_ATLANTIC_USDT);
        uint256 amount = vm.envOr("ASSETO_MANAGER_FORK_AMOUNT", TestConstants.OPENFI_FORK_ROUNDTRIP);
        _runAssetoManagedRoundtrip(assetoProduct, asset, amount);
    }

    function _runOpenFiManagedRoundtrip(address _openFiPool, address _asset, uint256 _amount) internal {
        ManagerContext memory ctx = _deployManagerContext();
        OpenFiDecoderAndSanitizer decoder = new OpenFiDecoderAndSanitizer(address(ctx.vault));

        deal(_asset, address(ctx.vault), _amount);
        uint256 vaultAssetsBefore = IERC20(_asset).balanceOf(address(ctx.vault));
        ManagePlan memory plan = _buildOpenFiPlan(address(decoder), _openFiPool, _asset, _amount, address(ctx.vault));
        _setRootAndManage(ctx, plan.leafHashes, plan.decoders, plan.targets, plan.targetData, plan.values);

        uint256 vaultAssetsAfter = IERC20(_asset).balanceOf(address(ctx.vault));
        assertGe(vaultAssetsAfter, vaultAssetsBefore - TestConstants.FORK_BALANCE_DUST_TOLERANCE);
    }

    function _runAssetoManagedRoundtrip(address _assetoProduct, address _asset, uint256 _amount) internal {
        ManagerContext memory ctx = _deployManagerContext();
        AssetoDecoderAndSanitizer decoder = new AssetoDecoderAndSanitizer(address(ctx.vault));

        assertGt(IAssetoProduct(_assetoProduct).getPrice(), 0);

        deal(_asset, address(ctx.vault), _amount);
        uint256 vaultAssetsBefore = IERC20(_asset).balanceOf(address(ctx.vault));
        ManagePlan memory plan = _buildAssetoPlan(address(decoder), _assetoProduct, _asset, _amount, address(ctx.vault));
        _setRootAndManage(ctx, plan.leafHashes, plan.decoders, plan.targets, plan.targetData, plan.values);

        uint256 vaultAssetsAfter = IERC20(_asset).balanceOf(address(ctx.vault));
        assertGe(vaultAssetsAfter, vaultAssetsBefore - TestConstants.FORK_BALANCE_DUST_TOLERANCE);
    }

    function _setRootAndManage(
        ManagerContext memory _ctx,
        bytes32[] memory _leafHashes,
        address[] memory _decoders,
        address[] memory _targets,
        bytes[] memory _targetData,
        uint256[] memory _values
    ) internal {
        bytes32[][] memory proofs = new bytes32[][](_leafHashes.length);
        bytes32 rootHash = ManagerMerkleLib.root(_leafHashes);
        for (uint256 i; i < _leafHashes.length; ++i) {
            proofs[i] = ManagerMerkleLib.proof(_leafHashes, i);
        }

        vm.prank(_ctx.managerAdmin);
        _ctx.manager.setManageRoot(_ctx.strategist, rootHash);

        vm.prank(_ctx.strategist);
        _ctx.manager.manageVaultWithMerkleVerification(proofs, _decoders, _targets, _targetData, _values);
    }

    function _buildOpenFiPlan(address _decoder, address _openFiPool, address _asset, uint256 _amount, address _vault)
        internal
        pure
        returns (ManagePlan memory _plan)
    {
        _plan.targets = new address[](3);
        _plan.targetData = new bytes[](3);
        _plan.values = new uint256[](3);
        _plan.decoders = new address[](3);
        _plan.leafHashes = new bytes32[](3);

        _plan.targets[0] = _asset;
        _plan.targetData[0] = abi.encodeWithSelector(IERC20.approve.selector, _openFiPool, _amount);
        _plan.leafHashes[0] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[0], 0, _plan.targetData[0], abi.encodePacked(_openFiPool)
        );

        _plan.targets[1] = _openFiPool;
        _plan.targetData[1] = OpenFiCallBuilder.supplyCalldata(_asset, _amount, _vault);
        _plan.leafHashes[1] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[1], 0, _plan.targetData[1], abi.encodePacked(_asset, _vault)
        );

        _plan.targets[2] = _openFiPool;
        _plan.targetData[2] = OpenFiCallBuilder.withdrawCalldata(_asset, _amount, _vault);
        _plan.leafHashes[2] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[2], 0, _plan.targetData[2], abi.encodePacked(_asset, _vault)
        );

        _plan.decoders[0] = _decoder;
        _plan.decoders[1] = _decoder;
        _plan.decoders[2] = _decoder;
    }

    function _buildAssetoPlan(address _decoder, address _assetoProduct, address _asset, uint256 _amount, address _vault)
        internal
        pure
        returns (ManagePlan memory _plan)
    {
        _plan.targets = new address[](3);
        _plan.targetData = new bytes[](3);
        _plan.values = new uint256[](3);
        _plan.decoders = new address[](3);
        _plan.leafHashes = new bytes32[](3);

        _plan.targets[0] = _asset;
        _plan.targetData[0] = abi.encodeWithSelector(IERC20.approve.selector, _assetoProduct, _amount);
        _plan.leafHashes[0] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[0], 0, _plan.targetData[0], abi.encodePacked(_assetoProduct)
        );

        _plan.targets[1] = _assetoProduct;
        _plan.targetData[1] = AssetoCallBuilder.subscribeCalldata(_vault, _amount);
        _plan.leafHashes[1] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[1], 0, _plan.targetData[1], abi.encodePacked(_vault)
        );

        _plan.targets[2] = _assetoProduct;
        _plan.targetData[2] = AssetoCallBuilder.redemptionCalldata(_vault, _amount);
        _plan.leafHashes[2] = ManagerMerkleLib.hashLeafFromCallData(
            _decoder, _plan.targets[2], 0, _plan.targetData[2], abi.encodePacked(_vault)
        );

        _plan.decoders[0] = _decoder;
        _plan.decoders[1] = _decoder;
        _plan.decoders[2] = _decoder;
    }

    function _deployManagerContext() internal returns (ManagerContext memory _ctx) {
        _ctx.vault = new BoringVault(address(this), "Pontus Manager Fork Vault", "pMFV", 18);
        _ctx.rolesAuthority = new RolesAuthority(address(this), Authority(TestConstants.ZERO_ADDRESS));
        _ctx.vault.setAuthority(_ctx.rolesAuthority);
        _ctx.manager = new ManagerWithMerkleVerification(address(this), address(_ctx.vault), TestConstants.ZERO_ADDRESS);
        _ctx.manager.setAuthority(_ctx.rolesAuthority);
        _ctx.strategist = makeAddr("strategist");
        _ctx.managerAdmin = makeAddr("managerAdmin");

        _configureManagerRoles(_ctx.rolesAuthority, _ctx.vault, _ctx.manager, _ctx.strategist, _ctx.managerAdmin);
    }

    function _configureManagerRoles(
        RolesAuthority _rolesAuthority,
        BoringVault _vault,
        ManagerWithMerkleVerification _manager,
        address _strategist,
        address _managerAdmin
    ) internal {
        _rolesAuthority.setRoleCapability(
            TestConstants.MANAGER_ROLE, address(_vault), BORING_VAULT_MANAGE_SINGLE_SELECTOR, true
        );
        _rolesAuthority.setRoleCapability(
            TestConstants.MANAGER_ROLE, address(_vault), BORING_VAULT_MANAGE_BATCH_SELECTOR, true
        );
        _rolesAuthority.setRoleCapability(
            TestConstants.STRATEGIST_ROLE,
            address(_manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        _rolesAuthority.setRoleCapability(
            TestConstants.MANAGER_INTERNAL_ROLE,
            address(_manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        _rolesAuthority.setRoleCapability(
            TestConstants.MANAGER_ADMIN_ROLE,
            address(_manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );

        _rolesAuthority.setUserRole(address(_manager), TestConstants.MANAGER_ROLE, true);
        _rolesAuthority.setUserRole(address(_manager), TestConstants.MANAGER_INTERNAL_ROLE, true);
        _rolesAuthority.setUserRole(_strategist, TestConstants.STRATEGIST_ROLE, true);
        _rolesAuthority.setUserRole(_managerAdmin, TestConstants.MANAGER_ADMIN_ROLE, true);
    }
}
