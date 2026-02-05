// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/console2.sol";

import {BaseScript} from "./BaseScript.sol";
import {BoringVault} from "../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {TrancheController} from "../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../src/tranche/TrancheRegistry.sol";
import {TrancheToken} from "../src/tranche/TrancheToken.sol";

contract Deploy is BaseScript {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;
    uint8 internal constant TELLER_ROLE = 9;

    function run() external {
        uint256 deployerKey = _envUint("PRIVATE_KEY", 0);
        require(deployerKey != 0, "PRIVATE_KEY missing");

        address owner = _envAddress("OWNER", vm.addr(deployerKey));
        address operator = _envAddress("OPERATOR", owner);
        address guardian = _envAddress("GUARDIAN", owner);
        address asset = _envAddress("ASSET", address(0));

        _requireAddress(asset, "ASSET");

        vm.startBroadcast(deployerKey);

        RolesAuthority rolesAuthority = new RolesAuthority(owner, Authority(address(0)));
        BoringVault vault = new BoringVault(owner, "Boring Vault", "BV", 18);
        vault.setAuthority(rolesAuthority);

        AccountantWithRateProviders accountant =
            new AccountantWithRateProviders(owner, address(vault), owner, 1e6, asset, 11_000, 9_000, 0, 0, 0);
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
        // Controllers are created later via TrancheFactory; operator gets interim teller-call role for setup checks.
        rolesAuthority.setUserRole(operator, TELLER_ROLE, true);

        TrancheController controllerImpl = new TrancheController();
        TrancheToken tokenImpl = new TrancheToken();
        TrancheRegistry registry = new TrancheRegistry(owner, address(0));
        TrancheFactory factory =
            new TrancheFactory(owner, address(controllerImpl), address(tokenImpl), address(registry));
        registry.setFactory(address(factory));

        vm.stopBroadcast();

        console2.log("RolesAuthority", address(rolesAuthority));
        console2.log("BoringVault", address(vault));
        console2.log("Accountant", address(accountant));
        console2.log("WETH", address(weth));
        console2.log("Teller", address(teller));
        console2.log("TrancheControllerImpl", address(controllerImpl));
        console2.log("TrancheTokenImpl", address(tokenImpl));
        console2.log("TrancheRegistry", address(registry));
        console2.log("TrancheFactory", address(factory));
        console2.log("Operator", operator);
        console2.log("Guardian", guardian);
    }
}
