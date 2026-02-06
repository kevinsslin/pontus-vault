// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/console2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BaseScript} from "./BaseScript.sol";
import {BoringVault} from "../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {TrancheFactory} from "../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../src/tranche/TrancheRegistry.sol";

contract DeployTrancheVault is BaseScript {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_ROLE = 9;

    function run() external {
        uint256 deployerKey = _envUint("PRIVATE_KEY", 0);
        require(deployerKey != 0, "PRIVATE_KEY missing");

        address owner = _envAddress("OWNER", vm.addr(deployerKey));
        address operator = _envAddress("OPERATOR", owner);
        address guardian = _envAddress("GUARDIAN", owner);
        address manager = _envAddress("MANAGER", owner);
        address asset = _envAddress("ASSET", address(0));
        address factoryAddress = _envAddress("TRANCHE_FACTORY", address(0));

        _requireAddress(asset, "ASSET");
        _requireAddress(factoryAddress, "TRANCHE_FACTORY");

        bytes32 paramsHash = _envBytes32("PARAMS_HASH", bytes32(0));
        uint256 seniorRatePerSecondWad = _envUint("SENIOR_RATE_PER_SECOND_WAD", 0);
        uint256 maxSeniorRatioBps = _envUint("MAX_SENIOR_RATIO_BPS", 8_000);
        string memory seniorName = _envString("SENIOR_TOKEN_NAME", "Pontus Vault Senior");
        string memory seniorSymbol = _envString("SENIOR_TOKEN_SYMBOL", "ptS");
        string memory juniorName = _envString("JUNIOR_TOKEN_NAME", "Pontus Vault Junior");
        string memory juniorSymbol = _envString("JUNIOR_TOKEN_SYMBOL", "ptJ");

        string memory boringVaultName = _envString("BORING_VAULT_NAME", "Pontus Vault Base");
        string memory boringVaultSymbol = _envString("BORING_VAULT_SYMBOL", "PTVB");
        uint8 boringVaultDecimals = uint8(_envUint("BORING_VAULT_DECIMALS", 18));

        uint96 accountantSharePrice = uint96(_envUint("ACCOUNTANT_SHARE_PRICE", 1e6));
        uint16 accountantUpperBoundBps = uint16(_envUint("ACCOUNTANT_UPPER_BOUND_BPS", 11_000));
        uint16 accountantLowerBoundBps = uint16(_envUint("ACCOUNTANT_LOWER_BOUND_BPS", 9_000));

        vm.startBroadcast(deployerKey);

        TrancheFactory factory = TrancheFactory(factoryAddress);

        RolesAuthority rolesAuthority = new RolesAuthority(owner, Authority(address(0)));
        BoringVault vault = new BoringVault(owner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
        vault.setAuthority(rolesAuthority);

        AccountantWithRateProviders accountant = new AccountantWithRateProviders(
            owner,
            address(vault),
            owner,
            accountantSharePrice,
            asset,
            accountantUpperBoundBps,
            accountantLowerBoundBps,
            0,
            0,
            0
        );

        WETH weth = new WETH();
        TellerWithMultiAssetSupport teller =
            new TellerWithMultiAssetSupport(owner, address(vault), address(accountant), address(weth));
        teller.updateAssetData(ERC20(asset), true, true, 0);
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

        uint8 tokenDecimals = IERC20Metadata(asset).decimals();
        uint256 vaultId = factory.createTrancheVault(
            TrancheFactory.TrancheVaultConfig({
                paramsHash: paramsHash,
                asset: asset,
                vault: address(vault),
                teller: address(teller),
                accountant: address(accountant),
                manager: manager,
                operator: operator,
                guardian: guardian,
                tokenDecimals: tokenDecimals,
                seniorRatePerSecondWad: seniorRatePerSecondWad,
                rateModel: address(0),
                maxSeniorRatioBps: maxSeniorRatioBps,
                seniorName: seniorName,
                seniorSymbol: seniorSymbol,
                juniorName: juniorName,
                juniorSymbol: juniorSymbol
            })
        );

        TrancheRegistry registry = TrancheRegistry(factory.registry());
        TrancheRegistry.TrancheVaultInfo memory info = registry.trancheVaults(vaultId);
        rolesAuthority.setUserRole(info.controller, TELLER_ROLE, true);

        vm.stopBroadcast();

        console2.log("RolesAuthority", address(rolesAuthority));
        console2.log("BoringVault", address(vault));
        console2.log("Accountant", address(accountant));
        console2.log("WETH", address(weth));
        console2.log("Teller", address(teller));
        console2.log("TrancheFactory", factoryAddress);
        console2.log("TrancheRegistry", address(registry));
        console2.log("TrancheVaultId", vaultId);
        console2.log("TrancheController", info.controller);
        console2.log("SeniorToken", info.seniorToken);
        console2.log("JuniorToken", info.juniorToken);
    }
}
