// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BoringVault} from "../../lib/boring-vault/src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "../../lib/boring-vault/src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "../../lib/boring-vault/lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "../../lib/boring-vault/lib/solmate/src/tokens/WETH.sol";

import {OpenFiDecoderAndSanitizer} from "../../src/decoders/OpenFiDecoderAndSanitizer.sol";
import {IAssetoProduct} from "../../src/interfaces/asseto/IAssetoProduct.sol";
import {ITrancheController} from "../../src/interfaces/tranche/ITrancheController.sol";
import {ManagerMerkleLib} from "../../src/libraries/ManagerMerkleLib.sol";
import {OpenFiCallBuilder} from "../../src/libraries/OpenFiCallBuilder.sol";
import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";

import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

import {BaseE2ETest} from "./BaseE2ETest.sol";

/// @title Tranche Lifecycle E2E Fork Test
/// @author Kevin Lin (@kevinsslin)
/// @notice Full E2E fork scenario:
/// 1) Build BoringVault + tranche stack.
/// 2) Simulate junior/senior user deposits.
/// 3) Let manager run OpenFi-managed yield operations.
/// 4) Simulate controlled strategy loss and verify tranche impact.
contract TrancheLifecycleForkTest is BaseE2ETest {
    bytes4 internal constant BORING_VAULT_MANAGE_SINGLE_SELECTOR = bytes4(keccak256("manage(address,bytes,uint256)"));
    bytes4 internal constant BORING_VAULT_MANAGE_BATCH_SELECTOR =
        bytes4(keccak256("manage(address[],bytes[],uint256[])"));

    struct ManagedCall {
        address decoder;
        address target;
        bytes targetData;
        uint256 value;
        bytes packedAddresses;
    }

    IERC20 internal asset;

    BoringVault internal boringVault;
    AccountantWithRateProviders internal accountant;
    TellerWithMultiAssetSupport internal teller;
    RolesAuthority internal rolesAuthority;
    WETH internal weth;

    TrancheController internal controller;
    TrancheToken internal seniorToken;
    TrancheToken internal juniorToken;

    ManagerWithMerkleVerification internal manager;
    OpenFiDecoderAndSanitizer internal openFiDecoder;

    address internal operator;
    address internal guardian;
    address internal juniorDepositor;
    address internal seniorDepositor;
    address internal strategist;
    address internal managerAdmin;
    address internal lossSink;

    /*//////////////////////////////////////////////////////////////
                      TRANCHE LIFECYCLE E2E TEST
    //////////////////////////////////////////////////////////////*/

    function test_tranche_lifecycle_end_to_end_on_pharos_fork() external {
        _createFork();

        uint256 juniorDepositAmount = 200 * TestConstants.ONE_USDC;
        uint256 seniorDepositAmount = 800 * TestConstants.ONE_USDC;
        uint256 openFiManagedAmount = 300 * TestConstants.ONE_USDC;
        uint256 moderateLossAmount = 150 * TestConstants.ONE_USDC;
        uint256 severeLossAmount = 120 * TestConstants.ONE_USDC;

        /*//////////////////////////////////////////////////////////////
                   STEP 1: CREATE BORINGVAULT + TRANCHE STACK
        //////////////////////////////////////////////////////////////*/
        _setActors();
        _deployBoringVaultStack();
        _deployTrancheStack();
        _deployManagerStack();

        /*//////////////////////////////////////////////////////////////
               STEP 2: DEPOSIT JUNIOR + DEPOSIT SENIOR (E2E)
        //////////////////////////////////////////////////////////////*/
        _seedAndDeposit(juniorDepositAmount, seniorDepositAmount);
        uint256 juniorShares = juniorToken.balanceOf(juniorDepositor);
        uint256 seniorShares = seniorToken.balanceOf(seniorDepositor);

        assertEq(controller.seniorDebt(), seniorDepositAmount);
        assertGt(juniorShares, 0);
        assertGt(seniorShares, 0);

        /*//////////////////////////////////////////////////////////////
              STEP 3: MANAGER CONTROLS YIELD VIA OPENFI CALLS
        //////////////////////////////////////////////////////////////*/
        uint256 vaultAssetsBeforeManage = asset.balanceOf(address(boringVault));
        _runManagedOpenFiRoundtrip(openFiManagedAmount);
        uint256 vaultAssetsAfterManage = asset.balanceOf(address(boringVault));
        uint256 totalAssetsBeforeLoss = controller.previewV();
        uint256 seniorDebt = controller.seniorDebt();

        assertGe(vaultAssetsAfterManage, vaultAssetsBeforeManage - TestDefaults.FORK_BALANCE_DUST_TOLERANCE);

        /*//////////////////////////////////////////////////////////////
                    STEP 4A: SIMULATE LOSS (JUNIOR-FIRST)
        //////////////////////////////////////////////////////////////*/
        _simulateManagedLoss(moderateLossAmount);
        uint256 expectedTotalAssetsAfterModerateLoss = totalAssetsBeforeLoss - moderateLossAmount;
        _assertWaterfallState(expectedTotalAssetsAfterModerateLoss, seniorDebt, juniorShares, seniorShares);

        /*//////////////////////////////////////////////////////////////
                  STEP 4B: DEEPER LOSS + EXTERNAL INTERACTION
        //////////////////////////////////////////////////////////////*/
        _simulateManagedLoss(severeLossAmount);
        uint256 expectedTotalAssetsAfterSevereLoss = expectedTotalAssetsAfterModerateLoss - severeLossAmount;
        _assertWaterfallState(expectedTotalAssetsAfterSevereLoss, seniorDebt, juniorShares, seniorShares);

        uint256 assetoPrice = IAssetoProduct(TestConstants.PHAROS_ATLANTIC_ASSETO_CASH_PLUS).getPrice();
        IAssetoProduct(TestConstants.PHAROS_ATLANTIC_ASSETO_CASH_PLUS).paused();
        assertGt(assetoPrice, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            STEP 1 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setActors() internal {
        operator = makeAddr("operator");
        guardian = makeAddr("guardian");
        juniorDepositor = makeAddr("juniorDepositor");
        seniorDepositor = makeAddr("seniorDepositor");
        strategist = makeAddr("strategist");
        managerAdmin = makeAddr("managerAdmin");
        lossSink = makeAddr("lossSink");
    }

    function _deployBoringVaultStack() internal {
        asset = IERC20(TestConstants.PHAROS_ATLANTIC_USDC);

        boringVault = new BoringVault(
            address(this),
            TestDefaults.BORING_VAULT_NAME,
            TestDefaults.BORING_VAULT_SYMBOL,
            TestConstants.BORING_VAULT_DECIMALS
        );
        accountant = new AccountantWithRateProviders(
            address(this),
            address(boringVault),
            address(this),
            uint96(TestDefaults.ACCOUNTANT_PEGGED_SHARE_PRICE),
            address(asset),
            uint16(TestDefaults.ACCOUNTANT_UPPER_BOUND_BPS),
            uint16(TestDefaults.ACCOUNTANT_LOWER_BOUND_BPS),
            TestDefaults.ACCOUNTANT_MIN_UPDATE_DELAY_SECONDS,
            TestDefaults.ACCOUNTANT_PLATFORM_FEE,
            TestDefaults.ACCOUNTANT_PERFORMANCE_FEE
        );
        accountant.updateLower(0);

        weth = new WETH();
        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(weth));
        teller.updateAssetData(ERC20(address(asset)), true, true, uint16(TestDefaults.TELLER_CREDIT_LIMIT));

        rolesAuthority = new RolesAuthority(address(this), Authority(TestConstants.ZERO_ADDRESS));
        boringVault.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(
            TestDefaults.MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true
        );
        rolesAuthority.setUserRole(address(teller), TestDefaults.MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TestDefaults.BURNER_ROLE, true);
        rolesAuthority.setRoleCapability(
            TestDefaults.TELLER_CALLER_ROLE, address(teller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            TestDefaults.TELLER_CALLER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
    }

    function _deployTrancheStack() internal {
        controller = new TrancheController();
        seniorToken = new TrancheToken();
        juniorToken = new TrancheToken();

        uint8 tokenDecimals = IERC20Metadata(address(asset)).decimals();
        seniorToken.initialize("Pontus E2E Senior", "ptE2ES", tokenDecimals, address(controller));
        juniorToken.initialize("Pontus E2E Junior", "ptE2EJ", tokenDecimals, address(controller));

        controller.initialize(
            ITrancheController.InitParams({
                asset: address(asset),
                vault: address(boringVault),
                teller: address(teller),
                accountant: address(accountant),
                operator: operator,
                guardian: guardian,
                seniorToken: address(seniorToken),
                juniorToken: address(juniorToken),
                seniorRatePerSecondWad: TestDefaults.DEFAULT_SENIOR_RATE_PER_SECOND_WAD,
                rateModel: TestConstants.ZERO_ADDRESS,
                maxSeniorRatioBps: TestDefaults.DEFAULT_MAX_SENIOR_RATIO_BPS,
                maxRateAge: TestDefaults.DEFAULT_MAX_RATE_AGE
            })
        );

        rolesAuthority.setUserRole(address(controller), TestDefaults.TELLER_CALLER_ROLE, true);
    }

    function _deployManagerStack() internal {
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), TestConstants.ZERO_ADDRESS);
        openFiDecoder = new OpenFiDecoderAndSanitizer(address(boringVault));
        manager.setAuthority(rolesAuthority);

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

        rolesAuthority.setUserRole(address(manager), TestDefaults.MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), TestDefaults.MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(strategist, TestDefaults.STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(managerAdmin, TestDefaults.MANAGER_ADMIN_ROLE, true);
    }

    /*//////////////////////////////////////////////////////////////
                            STEP 2 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _seedAndDeposit(uint256 _juniorAmount, uint256 _seniorAmount) internal {
        deal(address(asset), juniorDepositor, _juniorAmount);
        deal(address(asset), seniorDepositor, _seniorAmount);

        vm.startPrank(juniorDepositor);
        asset.approve(address(controller), _juniorAmount);
        controller.depositJunior(_juniorAmount, juniorDepositor);
        vm.stopPrank();

        vm.startPrank(seniorDepositor);
        asset.approve(address(controller), _seniorAmount);
        controller.depositSenior(_seniorAmount, seniorDepositor);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            STEP 3 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _runManagedOpenFiRoundtrip(uint256 _amount) internal {
        ManagedCall[] memory calls = new ManagedCall[](3);

        calls[0] = ManagedCall({
            decoder: address(openFiDecoder),
            target: address(asset),
            targetData: abi.encodeWithSelector(
                IERC20.approve.selector, TestConstants.PHAROS_ATLANTIC_OPENFI_POOL, _amount
            ),
            value: 0,
            packedAddresses: abi.encodePacked(TestConstants.PHAROS_ATLANTIC_OPENFI_POOL)
        });

        calls[1] = ManagedCall({
            decoder: address(openFiDecoder),
            target: TestConstants.PHAROS_ATLANTIC_OPENFI_POOL,
            targetData: OpenFiCallBuilder.supplyCalldata(address(asset), _amount, address(boringVault)),
            value: 0,
            packedAddresses: abi.encodePacked(address(asset), address(boringVault))
        });

        calls[2] = ManagedCall({
            decoder: address(openFiDecoder),
            target: TestConstants.PHAROS_ATLANTIC_OPENFI_POOL,
            targetData: OpenFiCallBuilder.withdrawCalldata(address(asset), type(uint256).max, address(boringVault)),
            value: 0,
            packedAddresses: abi.encodePacked(address(asset), address(boringVault))
        });

        _manage(calls);
        _syncAccountantExchangeRateToVaultAssets();
    }

    /*//////////////////////////////////////////////////////////////
                            STEP 4 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _simulateManagedLoss(uint256 _lossAmount) internal {
        ManagedCall[] memory calls = new ManagedCall[](1);
        calls[0] = ManagedCall({
            decoder: address(openFiDecoder),
            target: address(asset),
            targetData: abi.encodeWithSelector(IERC20.transfer.selector, lossSink, _lossAmount),
            value: 0,
            packedAddresses: abi.encodePacked(lossSink)
        });

        _manage(calls);
        _syncAccountantExchangeRateToVaultAssets();
    }

    function _syncAccountantExchangeRateToVaultAssets() internal {
        uint256 vaultTotalSupply = boringVault.totalSupply();
        if (vaultTotalSupply == 0) return;

        uint256 vaultAssets = asset.balanceOf(address(boringVault));
        uint256 exchangeRate = (vaultAssets * TestConstants.ONE_SHARE) / vaultTotalSupply;
        accountant.updateExchangeRate(uint96(exchangeRate));
    }

    function _assertWaterfallState(
        uint256 _expectedTotalAssets,
        uint256 _seniorDebt,
        uint256 _juniorShares,
        uint256 _seniorShares
    ) internal view {
        uint256 totalAssets = controller.previewV();
        uint256 expectedSeniorAssets = totalAssets < _seniorDebt ? totalAssets : _seniorDebt;
        uint256 expectedJuniorAssets = totalAssets > _seniorDebt ? totalAssets - _seniorDebt : 0;

        uint256 juniorAssets = controller.previewRedeemJunior(_juniorShares);
        uint256 seniorAssets = controller.previewRedeemSenior(_seniorShares);

        assertApproxEqAbs(totalAssets, _expectedTotalAssets, TestDefaults.FORK_BALANCE_DUST_TOLERANCE);
        assertApproxEqAbs(juniorAssets, expectedJuniorAssets, TestDefaults.FORK_BALANCE_DUST_TOLERANCE);
        assertApproxEqAbs(seniorAssets, expectedSeniorAssets, TestDefaults.FORK_BALANCE_DUST_TOLERANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          MANAGER MERKLE HELPER
    //////////////////////////////////////////////////////////////*/

    function _manage(ManagedCall[] memory _calls) internal {
        uint256 callsLength = _calls.length;
        address[] memory decoders = new address[](callsLength);
        address[] memory targets = new address[](callsLength);
        bytes[] memory targetData = new bytes[](callsLength);
        uint256[] memory values = new uint256[](callsLength);
        bytes32[] memory leafHashes = new bytes32[](callsLength);

        for (uint256 i; i < callsLength; ++i) {
            decoders[i] = _calls[i].decoder;
            targets[i] = _calls[i].target;
            targetData[i] = _calls[i].targetData;
            values[i] = _calls[i].value;
            leafHashes[i] = ManagerMerkleLib.hashLeafFromCallData(
                _calls[i].decoder, _calls[i].target, _calls[i].value, _calls[i].targetData, _calls[i].packedAddresses
            );
        }

        bytes32[][] memory proofs = new bytes32[][](callsLength);
        bytes32 rootHash = ManagerMerkleLib.root(leafHashes);
        for (uint256 i; i < callsLength; ++i) {
            proofs[i] = ManagerMerkleLib.proof(leafHashes, i);
        }

        vm.prank(managerAdmin);
        manager.setManageRoot(strategist, rootHash);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
    }
}
