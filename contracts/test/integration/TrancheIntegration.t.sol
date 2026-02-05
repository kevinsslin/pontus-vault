// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";

import {JuniorToken} from "../../src/tranche/JuniorToken.sol";
import {SeniorToken} from "../../src/tranche/SeniorToken.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {IERC20Minimal} from "../../src/interfaces/IERC20Minimal.sol";

import {BoringVaultTellerAdapter} from "../mocks/BoringVaultTellerAdapter.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract TrancheIntegrationTest is Test {
    uint8 internal constant MINTER_ROLE = 7;
    uint8 internal constant BURNER_ROLE = 8;

    MockERC20 internal asset;
    BoringVault internal vault;
    AccountantWithRateProviders internal accountant;
    RolesAuthority internal rolesAuthority;
    BoringVaultTellerAdapter internal adapter;

    TrancheController internal controller;
    SeniorToken internal seniorToken;
    JuniorToken internal juniorToken;

    address internal operator;
    address internal guardian;
    address internal alice;
    address internal bob;

    function setUp() public {
        operator = address(this);
        guardian = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        asset = new MockERC20("USDC", "USDC", 6);
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(vault), address(this), 1e6, address(asset), 11_000, 9_000, 0, 0, 0
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);

        adapter = new BoringVaultTellerAdapter(vault, accountant, IERC20Minimal(address(asset)));
        rolesAuthority.setUserRole(address(adapter), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(adapter), BURNER_ROLE, true);

        controller = new TrancheController();
        seniorToken = new SeniorToken();
        juniorToken = new JuniorToken();

        seniorToken.initialize("Pontus Vault Senior USDC S1", "pvS-USDC", 6, address(controller));
        juniorToken.initialize("Pontus Vault Junior USDC S1", "pvJ-USDC", 6, address(controller));

        controller.initialize(
            address(asset),
            address(vault),
            address(adapter),
            operator,
            guardian,
            address(seniorToken),
            address(juniorToken),
            0,
            address(0),
            8000
        );

        asset.mint(alice, 1_000_000e6);
        asset.mint(bob, 1_000_000e6);
    }

    function testDepositRedeemViaBoringVaultStack() public {
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

    function _depositSenior(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(controller), amount);
        controller.depositSenior(amount, user);
        vm.stopPrank();
    }

    function _depositJunior(address user, uint256 amount) internal {
        vm.startPrank(user);
        asset.approve(address(controller), amount);
        controller.depositJunior(amount, user);
        vm.stopPrank();
    }
}
