// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {BaseTest} from "../BaseTest.sol";

contract TrancheIntegrationTest is BaseTest {
    uint8 internal constant TELLER_CALLER_ROLE = 9;

    BoringVault internal vault;
    AccountantWithRateProviders internal accountant;
    TellerWithMultiAssetSupport internal teller;
    RolesAuthority internal rolesAuthority;
    WETH internal weth;

    function setUp() public {
        _initActors();
        _initRules();
        _deployCore("USDC", "USDC", 6);
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(vault), address(this), 1e6, address(asset), 11_000, 9_000, 0, 0, 0
        );

        weth = new WETH();
        teller = new TellerWithMultiAssetSupport(address(this), address(vault), address(accountant), address(weth));
        teller.updateAssetData(ERC20(address(asset)), true, true, 0);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setRoleCapability(
            TELLER_CALLER_ROLE, address(teller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_CALLER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        _initController(address(vault), address(teller), address(0), address(accountant));
        rolesAuthority.setUserRole(address(controller), TELLER_CALLER_ROLE, true);
        _seedBalances(1_000_000e6);
    }

    function test_depositRedeem_roundtripViaBoringVaultStack() public {
        _depositJunior(alice, 200e6);
        _depositSenior(bob, 800e6);

        assertEq(vault.balanceOf(address(controller)), 1000e18);

        uint256 seniorShares = seniorToken.balanceOf(bob);
        uint256 bobBalanceBefore = asset.balanceOf(bob);

        vm.startPrank(bob);
        seniorToken.approve(address(controller), seniorShares);
        controller.redeemSenior(seniorShares, bob);
        vm.stopPrank();

        assertEq(asset.balanceOf(bob), bobBalanceBefore + 800e6);
        assertEq(vault.balanceOf(address(controller)), 200e18);
    }

    // deposit helpers come from BaseTest
}
