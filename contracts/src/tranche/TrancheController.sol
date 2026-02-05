// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC20} from "../../lib/boring-vault/lib/solmate/src/tokens/ERC20.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";

import {Constants} from "../libraries/Constants.sol";
import {IBoringVaultTeller} from "../interfaces/IBoringVaultTeller.sol";
import {IRateModel} from "../interfaces/IRateModel.sol";
import {ITrancheToken} from "../interfaces/ITrancheToken.sol";

contract TrancheController is AccessControl, Initializable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error ZeroValue();
    error UnderwaterJunior();
    error InvalidBps();
    error MaxSeniorRatioExceeded();

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    struct InitParams {
        address asset;
        address vault;
        address teller;
        address accountant;
        address operator;
        address guardian;
        address seniorToken;
        address juniorToken;
        uint256 seniorRatePerSecondWad;
        address rateModel;
        uint256 maxSeniorRatioBps;
    }

    IERC20 public asset;
    AccountantWithRateProviders public accountant;
    IBoringVaultTeller public teller;
    ITrancheToken public seniorToken;
    ITrancheToken public juniorToken;

    uint256 public seniorDebt;
    uint256 public seniorRatePerSecondWad;
    address public rateModel;
    uint256 public lastAccrualTs;
    uint256 public maxSeniorRatioBps;
    address public vault;
    uint256 public oneShare;

    event Accrued(uint256 newSeniorDebt, uint256 dt);
    event SeniorRateUpdated(uint256 oldRate, uint256 newRate);
    event RateModelUpdated(address indexed oldModel, address indexed newModel);
    event TellerUpdated(address indexed oldTeller, address indexed newTeller);
    event MaxSeniorRatioUpdated(uint256 oldRatioBps, uint256 newRatioBps);

    event SeniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event JuniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event SeniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);
    event JuniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);

    function initialize(InitParams calldata params) external initializer {
        _validateInit(params);
        _setCore(params);
        _setRates(params);
        _setRoles(params);
    }

    function _validateInit(InitParams calldata params) internal pure {
        if (
            params.asset == address(0) ||
            params.vault == address(0) ||
            params.teller == address(0) ||
            params.accountant == address(0)
        ) {
            revert ZeroAddress();
        }
        if (params.operator == address(0) || params.guardian == address(0)) revert ZeroAddress();
        if (params.seniorToken == address(0) || params.juniorToken == address(0)) revert ZeroAddress();
        if (params.maxSeniorRatioBps > Constants.BPS) revert InvalidBps();
    }

    function _setCore(InitParams calldata params) internal {
        asset = IERC20(params.asset);
        vault = params.vault;
        oneShare = 10 ** IERC20Metadata(params.vault).decimals();
        teller = IBoringVaultTeller(params.teller);
        accountant = AccountantWithRateProviders(params.accountant);
        seniorToken = ITrancheToken(params.seniorToken);
        juniorToken = ITrancheToken(params.juniorToken);
        lastAccrualTs = block.timestamp;
    }

    function _setRates(InitParams calldata params) internal {
        seniorRatePerSecondWad = params.seniorRatePerSecondWad;
        rateModel = params.rateModel;
        maxSeniorRatioBps = params.maxSeniorRatioBps;
    }

    function _setRoles(InitParams calldata params) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, params.operator);
        _grantRole(OPERATOR_ROLE, params.operator);
        _grantRole(GUARDIAN_ROLE, params.guardian);
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    function setSeniorRatePerSecondWad(uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        accrue();
        emit SeniorRateUpdated(seniorRatePerSecondWad, newRate);
        seniorRatePerSecondWad = newRate;
    }

    function setRateModel(address newRateModel) external onlyRole(OPERATOR_ROLE) {
        accrue();
        emit RateModelUpdated(rateModel, newRateModel);
        rateModel = newRateModel;
    }

    function setTeller(address newTeller) external onlyRole(OPERATOR_ROLE) {
        if (newTeller == address(0)) revert ZeroAddress();
        emit TellerUpdated(address(teller), newTeller);
        teller = IBoringVaultTeller(newTeller);
    }

    function setMaxSeniorRatioBps(uint256 newRatioBps) external onlyRole(OPERATOR_ROLE) {
        if (newRatioBps > Constants.BPS) revert InvalidBps();
        emit MaxSeniorRatioUpdated(maxSeniorRatioBps, newRatioBps);
        maxSeniorRatioBps = newRatioBps;
    }

    function accrue() public {
        uint256 ts = block.timestamp;
        uint256 dt = ts - lastAccrualTs;
        if (dt == 0) return;

        lastAccrualTs = ts;

        uint256 D0 = seniorDebt;
        uint256 r = _currentRatePerSecondWad();
        if (D0 == 0 || r == 0) {
            emit Accrued(D0, dt);
            return;
        }

        uint256 interest = Math.mulDiv(D0, r, Constants.WAD) * dt;
        seniorDebt = D0 + interest;
        emit Accrued(seniorDebt, dt);
    }

    function previewV() public view returns (uint256) {
        uint256 shares = IERC20(vault).balanceOf(address(this));
        if (shares == 0) return 0;
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        if (rate == 0) return 0;
        return Math.mulDiv(shares, rate, oneShare);
    }

    function previewDepositSenior(uint256 assetsIn) external view returns (uint256 sharesOut) {
        if (assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) return assetsIn;
        if (seniorValue0 == 0) return 0;
        return Math.mulDiv(assetsIn, S0, seniorValue0);
    }

    function previewDepositJunior(uint256 assetsIn) external view returns (uint256 sharesOut) {
        if (assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        if (V0 < D0) return 0;
        uint256 J0 = juniorToken.totalSupply();
        uint256 juniorValue0 = _juniorValue(V0, D0);

        if (J0 == 0) return assetsIn;
        if (juniorValue0 == 0) return 0;
        return Math.mulDiv(assetsIn, J0, juniorValue0);
    }

    function previewRedeemSenior(uint256 sharesIn) external view returns (uint256 assetsOut) {
        if (sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        if (S0 == 0) return 0;
        uint256 seniorValue0 = _seniorValue(V0, D0);
        return Math.mulDiv(sharesIn, seniorValue0, S0);
    }

    function previewRedeemJunior(uint256 sharesIn) external view returns (uint256 assetsOut) {
        if (sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 J0 = juniorToken.totalSupply();
        if (J0 == 0) return 0;
        uint256 juniorValue0 = _juniorValue(V0, D0);
        return Math.mulDiv(sharesIn, juniorValue0, J0);
    }

    function depositSenior(uint256 assetsIn, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 sharesOut)
    {
        if (assetsIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) {
            sharesOut = assetsIn;
        } else {
            if (seniorValue0 == 0) revert ZeroValue();
            sharesOut = Math.mulDiv(assetsIn, S0, seniorValue0);
        }

        _enforceSeniorRatioCap(V0, D0, assetsIn);

        asset.safeTransferFrom(msg.sender, address(this), assetsIn);
        asset.forceApprove(address(teller), assetsIn);
        teller.deposit(asset, assetsIn, 0);

        seniorDebt = D0 + assetsIn;
        seniorToken.mint(receiver, sharesOut);
        emit SeniorDeposited(msg.sender, receiver, assetsIn, sharesOut);
    }

    function depositJunior(uint256 assetsIn, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 sharesOut)
    {
        if (assetsIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        if (V0 < D0) revert UnderwaterJunior();

        uint256 J0 = juniorToken.totalSupply();
        if (J0 == 0) {
            sharesOut = assetsIn;
        } else {
            uint256 juniorValue0 = _juniorValue(V0, D0);
            if (juniorValue0 == 0) revert ZeroValue();
            sharesOut = Math.mulDiv(assetsIn, J0, juniorValue0);
        }

        asset.safeTransferFrom(msg.sender, address(this), assetsIn);
        asset.forceApprove(address(teller), assetsIn);
        teller.deposit(asset, assetsIn, 0);

        juniorToken.mint(receiver, sharesOut);
        emit JuniorDeposited(msg.sender, receiver, assetsIn, sharesOut);
    }

    function redeemSenior(uint256 sharesIn, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assetsOut)
    {
        if (sharesIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) revert ZeroValue();
        assetsOut = Math.mulDiv(sharesIn, seniorValue0, S0);

        seniorToken.burnFrom(msg.sender, sharesIn);
        if (assetsOut != 0) {
            uint256 shareAmount = _sharesForAssets(assetsOut);
            seniorDebt = D0 - assetsOut;
            teller.bulkWithdraw(asset, shareAmount, assetsOut, receiver);
        }

        emit SeniorRedeemed(msg.sender, receiver, sharesIn, assetsOut);
    }

    function redeemJunior(uint256 sharesIn, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assetsOut)
    {
        if (sharesIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 J0 = juniorToken.totalSupply();
        uint256 juniorValue0 = _juniorValue(V0, D0);

        if (J0 == 0) revert ZeroValue();
        assetsOut = Math.mulDiv(sharesIn, juniorValue0, J0);

        juniorToken.burnFrom(msg.sender, sharesIn);
        if (assetsOut != 0) {
            uint256 shareAmount = _sharesForAssets(assetsOut);
            teller.bulkWithdraw(asset, shareAmount, assetsOut, receiver);
        }

        emit JuniorRedeemed(msg.sender, receiver, sharesIn, assetsOut);
    }

    function _currentRatePerSecondWad() internal view returns (uint256) {
        if (rateModel == address(0)) {
            return seniorRatePerSecondWad;
        }
        return IRateModel(rateModel).getRatePerSecondWad();
    }

    function _previewDebt() internal view returns (uint256) {
        uint256 D0 = seniorDebt;
        if (D0 == 0) return 0;
        uint256 r = _currentRatePerSecondWad();
        if (r == 0) return D0;
        uint256 dt = block.timestamp - lastAccrualTs;
        if (dt == 0) return D0;
        uint256 interest = Math.mulDiv(D0, r, Constants.WAD) * dt;
        return D0 + interest;
    }

    function _seniorValue(uint256 V, uint256 D) internal pure returns (uint256) {
        return V < D ? V : D;
    }

    function _juniorValue(uint256 V, uint256 D) internal pure returns (uint256) {
        return V > D ? (V - D) : 0;
    }

    function _enforceSeniorRatioCap(uint256 V0, uint256 D0, uint256 assetsIn) internal view {
        if (maxSeniorRatioBps == 0) return;
        uint256 V1 = V0 + assetsIn;
        uint256 D1 = D0 + assetsIn;
        uint256 ratioBps = Math.mulDiv(D1, Constants.BPS, V1);
        if (ratioBps > maxSeniorRatioBps) revert MaxSeniorRatioExceeded();
    }

    function _sharesForAssets(uint256 assets) internal view returns (uint256) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        if (rate == 0) return 0;
        uint256 shares = Math.mulDiv(assets, oneShare, rate);
        if (Math.mulDiv(shares, rate, oneShare) < assets) {
            shares += 1;
        }
        return shares;
    }
}
