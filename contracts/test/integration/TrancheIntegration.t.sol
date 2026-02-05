// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseTrancheTest} from "../BaseTrancheTest.sol";
import {BoringVaultTellerAdapter} from "../mocks/BoringVaultTellerAdapter.sol";

contract TrancheIntegrationTest is BaseTrancheTest {
    BoringVault internal vault;
    AccountantWithRateProviders internal accountant;
    RolesAuthority internal rolesAuthority;
    BoringVaultTellerAdapter internal adapter;

    function setUp() public {
        _initActors();
        _initRules();
        _deployCore("USDC", "USDC", 6);
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(vault), address(this), 1e6, address(asset), 11_000, 9_000, 0, 0, 0
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);

        adapter = new BoringVaultTellerAdapter(vault, accountant, IERC20(address(asset)));
        rolesAuthority.setUserRole(address(adapter), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(adapter), BURNER_ROLE, true);

        _initController(address(vault), address(adapter), address(0));
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

    // deposit helpers come from BaseTrancheTest
}
