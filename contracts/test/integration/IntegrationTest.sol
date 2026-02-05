// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {BaseTest} from "../BaseTest.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

abstract contract IntegrationTest is BaseTest {
    uint8 internal constant TELLER_CALLER_ROLE = 9;

    BoringVault internal boringVault;
    AccountantWithRateProviders internal boringVaultAccountant;
    TellerWithMultiAssetSupport internal boringVaultTeller;
    RolesAuthority internal rolesAuthority;
    WETH internal weth;

    function setUp() public virtual override {
        super.setUp();
        _deployBoringVaultStack();
    }

    function _deployBoringVaultStack() internal {
        boringVault = new BoringVault(
            address(this),
            TestDefaults.BORING_VAULT_NAME,
            TestDefaults.BORING_VAULT_SYMBOL,
            TestConstants.BORING_VAULT_DECIMALS
        );

        boringVaultAccountant = new AccountantWithRateProviders(
            address(this),
            address(boringVault),
            address(this),
            uint96(TestConstants.ACCOUNTANT_PEGGED_SHARE_PRICE),
            address(asset),
            uint16(TestConstants.ACCOUNTANT_UPPER_BOUND_BPS),
            uint16(TestConstants.ACCOUNTANT_LOWER_BOUND_BPS),
            0,
            0,
            0
        );

        weth = new WETH();
        boringVaultTeller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(boringVaultAccountant), address(weth)
        );
        boringVaultTeller.updateAssetData(ERC20(address(asset)), true, true, 0);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        boringVaultTeller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(boringVaultTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVaultTeller), BURNER_ROLE, true);
        rolesAuthority.setRoleCapability(
            TELLER_CALLER_ROLE, address(boringVaultTeller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_CALLER_ROLE, address(boringVaultTeller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
    }

    function _wireControllerToBoringVault(address rateModel) internal {
        _initController(address(boringVault), address(boringVaultTeller), rateModel, address(boringVaultAccountant));
        rolesAuthority.setUserRole(address(controller), TELLER_CALLER_ROLE, true);
    }
}
