// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {console2} from "forge-std/console2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BoringVault} from "../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "../lib/boring-vault/src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {AssetoDecoderAndSanitizer} from "../src/decoders/AssetoDecoderAndSanitizer.sol";
import {OpenFiDecoderAndSanitizer} from "../src/decoders/OpenFiDecoderAndSanitizer.sol";
import {ITrancheFactory} from "../src/interfaces/tranche/ITrancheFactory.sol";
import {ITrancheRegistry} from "../src/interfaces/tranche/ITrancheRegistry.sol";
import {BaseScript} from "./BaseScript.sol";

/// @title Deploy Tranche Vault
/// @author Kevin Lin (@kevinsslin)
/// @notice Deploys one full tranche vault stack, including manager + decoder wiring.
contract DeployTrancheVault is BaseScript {
    uint8 internal constant MANAGER_ROLE = 1;
    uint8 internal constant STRATEGIST_ROLE = 2;
    uint8 internal constant MANAGER_INTERNAL_ROLE = 3;
    uint8 internal constant MANAGER_ADMIN_ROLE = 4;
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_ROLE = 9;

    bytes4 internal constant BORING_VAULT_MANAGE_SINGLE_SELECTOR = bytes4(keccak256("manage(address,bytes,uint256)"));
    bytes4 internal constant BORING_VAULT_MANAGE_BATCH_SELECTOR =
        bytes4(keccak256("manage(address[],bytes[],uint256[])"));

    /// @notice Input configuration for one vault deployment.
    struct RunConfig {
        address owner;
        address operator;
        address guardian;
        address strategist;
        address managerAdmin;
        address balancerVault;
        address asset;
        address factoryAddress;
        uint256 seniorRatePerSecondWad;
        uint256 maxSeniorRatioBps;
        string seniorName;
        string seniorSymbol;
        string juniorName;
        string juniorSymbol;
        string boringVaultName;
        string boringVaultSymbol;
        uint8 boringVaultDecimals;
        uint96 accountantSharePrice;
        uint16 accountantUpperBoundBps;
        uint16 accountantLowerBoundBps;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Entry point for one vault deployment.
    function run() external {
        uint256 deployerKey = _envUint("PRIVATE_KEY", 0);
        require(deployerKey != 0, "PRIVATE_KEY missing");

        RunConfig memory cfg = _loadConfig(deployerKey);

        vm.startBroadcast(deployerKey);

        ITrancheFactory factory = ITrancheFactory(cfg.factoryAddress);
        RolesAuthority rolesAuthority = new RolesAuthority(cfg.owner, Authority(address(0)));
        BoringVault vault =
            new BoringVault(cfg.owner, cfg.boringVaultName, cfg.boringVaultSymbol, cfg.boringVaultDecimals);
        vault.setAuthority(rolesAuthority);

        AccountantWithRateProviders accountant = new AccountantWithRateProviders(
            cfg.owner,
            address(vault),
            cfg.owner,
            cfg.accountantSharePrice,
            cfg.asset,
            cfg.accountantUpperBoundBps,
            cfg.accountantLowerBoundBps,
            0,
            0,
            0
        );

        WETH weth = new WETH();
        TellerWithMultiAssetSupport teller =
            new TellerWithMultiAssetSupport(cfg.owner, address(vault), address(accountant), address(weth));
        teller.updateAssetData(ERC20(cfg.asset), true, true, 0);
        teller.setAuthority(rolesAuthority);

        ManagerWithMerkleVerification manager =
            new ManagerWithMerkleVerification(cfg.owner, address(vault), cfg.balancerVault);
        OpenFiDecoderAndSanitizer openFiDecoder = new OpenFiDecoderAndSanitizer(address(vault));
        AssetoDecoderAndSanitizer assetoDecoder = new AssetoDecoderAndSanitizer(address(vault));
        manager.setAuthority(rolesAuthority);

        _wireTellerRoles(rolesAuthority, vault, teller);
        _wireManagerRoles(rolesAuthority, vault, manager, cfg.strategist, cfg.managerAdmin);

        uint8 tokenDecimals = IERC20Metadata(cfg.asset).decimals();
        bytes32 paramsHash = factory.createTrancheVault(
            ITrancheFactory.TrancheVaultConfig({
                asset: cfg.asset,
                vault: address(vault),
                teller: address(teller),
                accountant: address(accountant),
                manager: address(manager),
                operator: cfg.operator,
                guardian: cfg.guardian,
                tokenDecimals: tokenDecimals,
                seniorRatePerSecondWad: cfg.seniorRatePerSecondWad,
                rateModel: address(0),
                maxSeniorRatioBps: cfg.maxSeniorRatioBps,
                seniorName: cfg.seniorName,
                seniorSymbol: cfg.seniorSymbol,
                juniorName: cfg.juniorName,
                juniorSymbol: cfg.juniorSymbol
            })
        );

        ITrancheRegistry registry = ITrancheRegistry(factory.registry());
        ITrancheRegistry.TrancheVaultInfo memory info = registry.trancheVaultByParamsHash(paramsHash);
        rolesAuthority.setUserRole(info.controller, TELLER_ROLE, true);

        vm.stopBroadcast();

        console2.log("RolesAuthority", address(rolesAuthority));
        console2.log("BoringVault", address(vault));
        console2.log("Accountant", address(accountant));
        console2.log("WETH", address(weth));
        console2.log("Teller", address(teller));
        console2.log("Manager", address(manager));
        console2.log("OpenFiDecoderAndSanitizer", address(openFiDecoder));
        console2.log("AssetoDecoderAndSanitizer", address(assetoDecoder));
        console2.log("TrancheFactory", cfg.factoryAddress);
        console2.log("TrancheRegistry", address(registry));
        console2.log("TrancheParamsHash");
        console2.logBytes32(paramsHash);
        console2.log("TrancheController", info.controller);
        console2.log("SeniorToken", info.seniorToken);
        console2.log("JuniorToken", info.juniorToken);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Loads deploy config from environment with defaults.
    /// @param _deployerKey Broadcast key used to derive default owner.
    /// @return cfg Parsed config.
    function _loadConfig(uint256 _deployerKey) internal view returns (RunConfig memory cfg) {
        cfg.owner = _envAddress("OWNER", vm.addr(_deployerKey));
        cfg.operator = _envAddress("OPERATOR", cfg.owner);
        cfg.guardian = _envAddress("GUARDIAN", cfg.owner);
        cfg.strategist = _envAddress("STRATEGIST", cfg.operator);
        cfg.managerAdmin = _envAddress("MANAGER_ADMIN", cfg.owner);
        cfg.balancerVault = _envAddress("BALANCER_VAULT", address(0));
        cfg.asset = _envAddress("ASSET", address(0));
        cfg.factoryAddress = _envAddress("TRANCHE_FACTORY", address(0));
        _requireAddress(cfg.asset, "ASSET");
        _requireAddress(cfg.factoryAddress, "TRANCHE_FACTORY");
        _requireAddress(cfg.strategist, "STRATEGIST");
        _requireAddress(cfg.managerAdmin, "MANAGER_ADMIN");

        cfg.seniorRatePerSecondWad = _envUint("SENIOR_RATE_PER_SECOND_WAD", 0);
        cfg.maxSeniorRatioBps = _envUint("MAX_SENIOR_RATIO_BPS", 8_000);
        cfg.seniorName = _envString("SENIOR_TOKEN_NAME", "Pontus Vault Senior");
        cfg.seniorSymbol = _envString("SENIOR_TOKEN_SYMBOL", "ptS");
        cfg.juniorName = _envString("JUNIOR_TOKEN_NAME", "Pontus Vault Junior");
        cfg.juniorSymbol = _envString("JUNIOR_TOKEN_SYMBOL", "ptJ");
        cfg.boringVaultName = _envString("BORING_VAULT_NAME", "Pontus Vault Base");
        cfg.boringVaultSymbol = _envString("BORING_VAULT_SYMBOL", "PTVB");
        cfg.boringVaultDecimals = uint8(_envUint("BORING_VAULT_DECIMALS", 18));
        cfg.accountantSharePrice = uint96(_envUint("ACCOUNTANT_SHARE_PRICE", 1e6));
        cfg.accountantUpperBoundBps = uint16(_envUint("ACCOUNTANT_UPPER_BOUND_BPS", 11_000));
        cfg.accountantLowerBoundBps = uint16(_envUint("ACCOUNTANT_LOWER_BOUND_BPS", 9_000));
    }

    /// @notice Wires teller mint/burn and user-call capabilities.
    /// @param _rolesAuthority Shared authority contract.
    /// @param _vault BoringVault address.
    /// @param _teller Teller contract address.
    function _wireTellerRoles(RolesAuthority _rolesAuthority, BoringVault _vault, TellerWithMultiAssetSupport _teller)
        internal
    {
        _rolesAuthority.setRoleCapability(MINTER_ROLE, address(_vault), BoringVault.enter.selector, true);
        _rolesAuthority.setRoleCapability(BURNER_ROLE, address(_vault), BoringVault.exit.selector, true);
        _rolesAuthority.setUserRole(address(_teller), MINTER_ROLE, true);
        _rolesAuthority.setUserRole(address(_teller), BURNER_ROLE, true);
        _rolesAuthority.setRoleCapability(
            TELLER_ROLE, address(_teller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        _rolesAuthority.setRoleCapability(
            TELLER_ROLE, address(_teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
    }

    /// @notice Wires manager execution and root admin capabilities.
    /// @param _rolesAuthority Shared authority contract.
    /// @param _vault BoringVault address.
    /// @param _manager Manager contract.
    /// @param _strategist Strategist authorized to execute managed calls.
    /// @param _managerAdmin Admin authorized to set merkle root and pause manager.
    function _wireManagerRoles(
        RolesAuthority _rolesAuthority,
        BoringVault _vault,
        ManagerWithMerkleVerification _manager,
        address _strategist,
        address _managerAdmin
    ) internal {
        _rolesAuthority.setRoleCapability(MANAGER_ROLE, address(_vault), BORING_VAULT_MANAGE_SINGLE_SELECTOR, true);
        _rolesAuthority.setRoleCapability(MANAGER_ROLE, address(_vault), BORING_VAULT_MANAGE_BATCH_SELECTOR, true);
        _rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(_manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        _rolesAuthority.setRoleCapability(
            MANAGER_INTERNAL_ROLE,
            address(_manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        _rolesAuthority.setRoleCapability(
            MANAGER_ADMIN_ROLE, address(_manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        _rolesAuthority.setRoleCapability(
            MANAGER_ADMIN_ROLE, address(_manager), ManagerWithMerkleVerification.pause.selector, true
        );
        _rolesAuthority.setRoleCapability(
            MANAGER_ADMIN_ROLE, address(_manager), ManagerWithMerkleVerification.unpause.selector, true
        );

        _rolesAuthority.setUserRole(address(_manager), MANAGER_ROLE, true);
        _rolesAuthority.setUserRole(address(_manager), MANAGER_INTERNAL_ROLE, true);
        _rolesAuthority.setUserRole(_strategist, STRATEGIST_ROLE, true);
        _rolesAuthority.setUserRole(_managerAdmin, MANAGER_ADMIN_ROLE, true);
    }
}
