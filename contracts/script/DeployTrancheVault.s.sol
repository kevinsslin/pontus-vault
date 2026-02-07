// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/console2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BaseScript} from "./BaseScript.sol";
import {BoringVault} from "../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {ITrancheFactory} from "../src/interfaces/ITrancheFactory.sol";
import {ITrancheRegistry} from "../src/interfaces/ITrancheRegistry.sol";

contract DeployTrancheVault is BaseScript {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_ROLE = 9;

    struct RunConfig {
        address owner;
        address operator;
        address guardian;
        address manager;
        address asset;
        address factoryAddress;
        bytes32 paramsHash;
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

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setRoleCapability(
            TELLER_ROLE, address(teller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        uint8 tokenDecimals = IERC20Metadata(cfg.asset).decimals();
        bytes32 paramsHash = factory.createTrancheVault(
            ITrancheFactory.TrancheVaultConfig({
                paramsHash: cfg.paramsHash,
                asset: cfg.asset,
                vault: address(vault),
                teller: address(teller),
                accountant: address(accountant),
                manager: cfg.manager,
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
        console2.log("TrancheFactory", cfg.factoryAddress);
        console2.log("TrancheRegistry", address(registry));
        console2.log("TrancheParamsHash");
        console2.logBytes32(paramsHash);
        console2.log("TrancheController", info.controller);
        console2.log("SeniorToken", info.seniorToken);
        console2.log("JuniorToken", info.juniorToken);
    }

    function _loadConfig(uint256 deployerKey) internal view returns (RunConfig memory cfg) {
        cfg.owner = _envAddress("OWNER", vm.addr(deployerKey));
        cfg.operator = _envAddress("OPERATOR", cfg.owner);
        cfg.guardian = _envAddress("GUARDIAN", cfg.owner);
        cfg.manager = _envAddress("MANAGER", cfg.owner);
        cfg.asset = _envAddress("ASSET", address(0));
        cfg.factoryAddress = _envAddress("TRANCHE_FACTORY", address(0));
        _requireAddress(cfg.asset, "ASSET");
        _requireAddress(cfg.factoryAddress, "TRANCHE_FACTORY");

        cfg.paramsHash = _envBytes32("PARAMS_HASH", bytes32(0));
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
}
