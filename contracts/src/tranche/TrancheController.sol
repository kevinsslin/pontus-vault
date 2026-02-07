// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

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
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";

import {Constants} from "../libraries/Constants.sol";
import {IRateModel} from "../interfaces/rates/IRateModel.sol";
import {ITrancheController} from "../interfaces/tranche/ITrancheController.sol";
import {ITrancheToken} from "../interfaces/tranche/ITrancheToken.sol";

/// @title Tranche Controller
/// @author Kevin Lin (@kevinsslin)
/// @notice Handles tranche accounting, debt accrual, and user flow between asset and tranche tokens.
contract TrancheController is ITrancheController, AccessControl, Initializable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc ITrancheController
    bytes32 public constant override OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /// @inheritdoc ITrancheController
    bytes32 public constant override GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @inheritdoc ITrancheController
    IERC20 public asset;
    /// @inheritdoc ITrancheController
    AccountantWithRateProviders public accountant;
    /// @inheritdoc ITrancheController
    TellerWithMultiAssetSupport public teller;
    /// @inheritdoc ITrancheController
    ITrancheToken public seniorToken;
    /// @inheritdoc ITrancheController
    ITrancheToken public juniorToken;

    /// @inheritdoc ITrancheController
    uint256 public seniorDebt;
    /// @inheritdoc ITrancheController
    uint256 public seniorRatePerSecondWad;
    /// @inheritdoc ITrancheController
    address public rateModel;
    /// @inheritdoc ITrancheController
    uint256 public lastAccrualTs;
    /// @inheritdoc ITrancheController
    uint256 public maxSeniorRatioBps;
    /// @inheritdoc ITrancheController
    address public vault;
    /// @inheritdoc ITrancheController
    uint256 public oneShare;

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function initialize(InitParams calldata _params) external override initializer {
        _validateInit(_params);
        _setCore(_params);
        _setRates(_params);
        _setRoles(_params);
    }

    /*//////////////////////////////////////////////////////////////
                           GUARDIAN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function pause() external override onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /// @inheritdoc ITrancheController
    function unpause() external override onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                           OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function setSeniorRatePerSecondWad(uint256 _newRate) external override onlyRole(OPERATOR_ROLE) {
        accrue();
        emit SeniorRateUpdated(seniorRatePerSecondWad, _newRate);
        seniorRatePerSecondWad = _newRate;
    }

    /// @inheritdoc ITrancheController
    function setRateModel(address _newRateModel) external override onlyRole(OPERATOR_ROLE) {
        accrue();
        emit RateModelUpdated(rateModel, _newRateModel);
        rateModel = _newRateModel;
    }

    /// @inheritdoc ITrancheController
    function setTeller(address _newTeller) external override onlyRole(OPERATOR_ROLE) {
        if (_newTeller == address(0)) revert ZeroAddress();
        emit TellerUpdated(address(teller), _newTeller);
        teller = TellerWithMultiAssetSupport(payable(_newTeller));
    }

    /// @inheritdoc ITrancheController
    function setMaxSeniorRatioBps(uint256 _newRatioBps) external override onlyRole(OPERATOR_ROLE) {
        if (_newRatioBps > Constants.BPS) revert InvalidBps();
        emit MaxSeniorRatioUpdated(maxSeniorRatioBps, _newRatioBps);
        maxSeniorRatioBps = _newRatioBps;
    }

    /*//////////////////////////////////////////////////////////////
                             USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function depositSenior(uint256 _assetsIn, address _receiver)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 _sharesOut)
    {
        if (_assetsIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) {
            _sharesOut = _assetsIn;
        } else {
            if (seniorValue0 == 0) revert ZeroValue();
            _sharesOut = Math.mulDiv(_assetsIn, S0, seniorValue0);
        }

        _enforceSeniorRatioCap(V0, D0, _assetsIn);

        asset.safeTransferFrom(msg.sender, address(this), _assetsIn);
        asset.forceApprove(vault, _assetsIn);
        teller.deposit(ERC20(address(asset)), _assetsIn, 0);

        seniorDebt = D0 + _assetsIn;
        seniorToken.mint(_receiver, _sharesOut);
        emit SeniorDeposited(msg.sender, _receiver, _assetsIn, _sharesOut);
    }

    /// @inheritdoc ITrancheController
    function depositJunior(uint256 _assetsIn, address _receiver)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 _sharesOut)
    {
        if (_assetsIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        if (V0 < D0) revert UnderwaterJunior();

        uint256 J0 = juniorToken.totalSupply();
        if (J0 == 0) {
            _sharesOut = _assetsIn;
        } else {
            uint256 juniorValue0 = _juniorValue(V0, D0);
            if (juniorValue0 == 0) revert ZeroValue();
            _sharesOut = Math.mulDiv(_assetsIn, J0, juniorValue0);
        }

        asset.safeTransferFrom(msg.sender, address(this), _assetsIn);
        asset.forceApprove(vault, _assetsIn);
        teller.deposit(ERC20(address(asset)), _assetsIn, 0);

        juniorToken.mint(_receiver, _sharesOut);
        emit JuniorDeposited(msg.sender, _receiver, _assetsIn, _sharesOut);
    }

    /// @inheritdoc ITrancheController
    function redeemSenior(uint256 _sharesIn, address _receiver)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 _assetsOut)
    {
        if (_sharesIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) revert ZeroValue();
        _assetsOut = Math.mulDiv(_sharesIn, seniorValue0, S0);

        seniorToken.burnFrom(msg.sender, _sharesIn);
        if (_assetsOut != 0) {
            uint256 shareAmount = _sharesForAssets(_assetsOut);
            seniorDebt = D0 - _assetsOut;
            teller.bulkWithdraw(ERC20(address(asset)), shareAmount, _assetsOut, _receiver);
        }

        emit SeniorRedeemed(msg.sender, _receiver, _sharesIn, _assetsOut);
    }

    /// @inheritdoc ITrancheController
    function redeemJunior(uint256 _sharesIn, address _receiver)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 _assetsOut)
    {
        if (_sharesIn == 0) revert ZeroAmount();

        accrue();

        uint256 V0 = previewV();
        uint256 D0 = seniorDebt;
        uint256 J0 = juniorToken.totalSupply();
        uint256 juniorValue0 = _juniorValue(V0, D0);

        if (J0 == 0) revert ZeroValue();
        _assetsOut = Math.mulDiv(_sharesIn, juniorValue0, J0);

        juniorToken.burnFrom(msg.sender, _sharesIn);
        if (_assetsOut != 0) {
            uint256 shareAmount = _sharesForAssets(_assetsOut);
            teller.bulkWithdraw(ERC20(address(asset)), shareAmount, _assetsOut, _receiver);
        }

        emit JuniorRedeemed(msg.sender, _receiver, _sharesIn, _assetsOut);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function previewDepositSenior(uint256 _assetsIn) external view override returns (uint256 _sharesOut) {
        if (_assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) return _assetsIn;
        if (seniorValue0 == 0) return 0;
        return Math.mulDiv(_assetsIn, S0, seniorValue0);
    }

    /// @inheritdoc ITrancheController
    function previewDepositJunior(uint256 _assetsIn) external view override returns (uint256 _sharesOut) {
        if (_assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        if (V0 < D0) return 0;
        uint256 J0 = juniorToken.totalSupply();
        uint256 juniorValue0 = _juniorValue(V0, D0);

        if (J0 == 0) return _assetsIn;
        if (juniorValue0 == 0) return 0;
        return Math.mulDiv(_assetsIn, J0, juniorValue0);
    }

    /// @inheritdoc ITrancheController
    function previewRedeemSenior(uint256 _sharesIn) external view override returns (uint256 _assetsOut) {
        if (_sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        if (S0 == 0) return 0;
        uint256 seniorValue0 = _seniorValue(V0, D0);
        return Math.mulDiv(_sharesIn, seniorValue0, S0);
    }

    /// @inheritdoc ITrancheController
    function previewRedeemJunior(uint256 _sharesIn) external view override returns (uint256 _assetsOut) {
        if (_sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 J0 = juniorToken.totalSupply();
        if (J0 == 0) return 0;
        uint256 juniorValue0 = _juniorValue(V0, D0);
        return Math.mulDiv(_sharesIn, juniorValue0, J0);
    }

    /*//////////////////////////////////////////////////////////////
                          ACCOUNTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheController
    function accrue() public override {
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

    /// @inheritdoc ITrancheController
    function previewV() public view override returns (uint256) {
        uint256 shares = IERC20(vault).balanceOf(address(this));
        if (shares == 0) return 0;
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        if (rate == 0) return 0;
        return Math.mulDiv(shares, rate, oneShare);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates initialization payload.
    /// @param _params Initialization parameter bundle.
    function _validateInit(InitParams calldata _params) internal pure {
        if (
            _params.asset == address(0) || _params.vault == address(0) || _params.teller == address(0)
                || _params.accountant == address(0)
        ) {
            revert ZeroAddress();
        }
        if (_params.operator == address(0) || _params.guardian == address(0)) revert ZeroAddress();
        if (_params.seniorToken == address(0) || _params.juniorToken == address(0)) revert ZeroAddress();
        if (_params.maxSeniorRatioBps > Constants.BPS) revert InvalidBps();
    }

    /// @notice Sets core protocol dependencies and baseline accounting state.
    /// @param _params Initialization parameter bundle.
    function _setCore(InitParams calldata _params) internal {
        asset = IERC20(_params.asset);
        vault = _params.vault;
        oneShare = 10 ** IERC20Metadata(_params.vault).decimals();
        teller = TellerWithMultiAssetSupport(payable(_params.teller));
        accountant = AccountantWithRateProviders(_params.accountant);
        seniorToken = ITrancheToken(_params.seniorToken);
        juniorToken = ITrancheToken(_params.juniorToken);
        lastAccrualTs = block.timestamp;
    }

    /// @notice Sets rate configuration values.
    /// @param _params Initialization parameter bundle.
    function _setRates(InitParams calldata _params) internal {
        seniorRatePerSecondWad = _params.seniorRatePerSecondWad;
        rateModel = _params.rateModel;
        maxSeniorRatioBps = _params.maxSeniorRatioBps;
    }

    /// @notice Grants admin/operator/guardian roles.
    /// @param _params Initialization parameter bundle.
    function _setRoles(InitParams calldata _params) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, _params.operator);
        _grantRole(OPERATOR_ROLE, _params.operator);
        _grantRole(GUARDIAN_ROLE, _params.guardian);
    }

    /// @notice Resolves the active per-second WAD rate.
    /// @dev Returns static rate when no `rateModel` is configured.
    /// @return _ratePerSecondWad Current accrual rate.
    function _currentRatePerSecondWad() internal view returns (uint256) {
        if (rateModel == address(0)) {
            return seniorRatePerSecondWad;
        }
        return IRateModel(rateModel).getRatePerSecondWad();
    }

    /// @notice Previews senior debt including unaccrued interval from `lastAccrualTs`.
    /// @return _debtPreview Debt value after hypothetical accrual to current timestamp.
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

    /// @notice Returns senior claimable value as `min(V, D)`.
    /// @param _v Current vault value.
    /// @param _d Current senior debt.
    /// @return _value Senior claimable value.
    function _seniorValue(uint256 _v, uint256 _d) internal pure returns (uint256) {
        return _v < _d ? _v : _d;
    }

    /// @notice Returns junior residual value as `max(V - D, 0)`.
    /// @param _v Current vault value.
    /// @param _d Current senior debt.
    /// @return _value Junior residual value.
    function _juniorValue(uint256 _v, uint256 _d) internal pure returns (uint256) {
        return _v > _d ? (_v - _d) : 0;
    }

    /// @notice Enforces max senior ratio using post-deposit state.
    /// @param _v0 Current vault value.
    /// @param _d0 Current senior debt.
    /// @param _assetsIn Proposed senior deposit amount.
    function _enforceSeniorRatioCap(uint256 _v0, uint256 _d0, uint256 _assetsIn) internal view {
        if (maxSeniorRatioBps == 0) return;
        uint256 V1 = _v0 + _assetsIn;
        uint256 D1 = _d0 + _assetsIn;
        uint256 ratioBps = Math.mulDiv(D1, Constants.BPS, V1);
        if (ratioBps > maxSeniorRatioBps) revert MaxSeniorRatioExceeded();
    }

    /// @notice Converts target assets into required vault shares with round-up.
    /// @param _assets Asset amount target.
    /// @return _shares Vault shares required.
    function _sharesForAssets(uint256 _assets) internal view returns (uint256) {
        uint256 rate = accountant.getRateInQuoteSafe(ERC20(address(asset)));
        if (rate == 0) return 0;
        uint256 shares = Math.mulDiv(_assets, oneShare, rate);
        if (Math.mulDiv(shares, rate, oneShare) < _assets) {
            shares += 1;
        }
        return shares;
    }
}
