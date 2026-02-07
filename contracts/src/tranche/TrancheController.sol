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
    TellerWithMultiAssetSupport public teller;
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

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function initialize(InitParams calldata _params) external initializer {
        _validateInit(_params);
        _setCore(_params);
        _setRates(_params);
        _setRoles(_params);
    }

    /*//////////////////////////////////////////////////////////////
                           GUARDIAN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                           OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSeniorRatePerSecondWad(uint256 _newRate) external onlyRole(OPERATOR_ROLE) {
        accrue();
        emit SeniorRateUpdated(seniorRatePerSecondWad, _newRate);
        seniorRatePerSecondWad = _newRate;
    }

    function setRateModel(address _newRateModel) external onlyRole(OPERATOR_ROLE) {
        accrue();
        emit RateModelUpdated(rateModel, _newRateModel);
        rateModel = _newRateModel;
    }

    function setTeller(address _newTeller) external onlyRole(OPERATOR_ROLE) {
        if (_newTeller == address(0)) revert ZeroAddress();
        emit TellerUpdated(address(teller), _newTeller);
        teller = TellerWithMultiAssetSupport(payable(_newTeller));
    }

    function setMaxSeniorRatioBps(uint256 _newRatioBps) external onlyRole(OPERATOR_ROLE) {
        if (_newRatioBps > Constants.BPS) revert InvalidBps();
        emit MaxSeniorRatioUpdated(maxSeniorRatioBps, _newRatioBps);
        maxSeniorRatioBps = _newRatioBps;
    }

    /*//////////////////////////////////////////////////////////////
                            USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositSenior(uint256 _assetsIn, address _receiver)
        external
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

    function depositJunior(uint256 _assetsIn, address _receiver)
        external
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

    function redeemSenior(uint256 _sharesIn, address _receiver)
        external
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

    function redeemJunior(uint256 _sharesIn, address _receiver)
        external
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

    function previewDepositSenior(uint256 _assetsIn) external view returns (uint256 _sharesOut) {
        if (_assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) return _assetsIn;
        if (seniorValue0 == 0) return 0;
        return Math.mulDiv(_assetsIn, S0, seniorValue0);
    }

    function previewDepositJunior(uint256 _assetsIn) external view returns (uint256 _sharesOut) {
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

    function previewRedeemSenior(uint256 _sharesIn) external view returns (uint256 _assetsOut) {
        if (_sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        if (S0 == 0) return 0;
        uint256 seniorValue0 = _seniorValue(V0, D0);
        return Math.mulDiv(_sharesIn, seniorValue0, S0);
    }

    function previewRedeemJunior(uint256 _sharesIn) external view returns (uint256 _assetsOut) {
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

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function _setRates(InitParams calldata _params) internal {
        seniorRatePerSecondWad = _params.seniorRatePerSecondWad;
        rateModel = _params.rateModel;
        maxSeniorRatioBps = _params.maxSeniorRatioBps;
    }

    function _setRoles(InitParams calldata _params) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, _params.operator);
        _grantRole(OPERATOR_ROLE, _params.operator);
        _grantRole(GUARDIAN_ROLE, _params.guardian);
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

    function _seniorValue(uint256 _v, uint256 _d) internal pure returns (uint256) {
        return _v < _d ? _v : _d;
    }

    function _juniorValue(uint256 _v, uint256 _d) internal pure returns (uint256) {
        return _v > _d ? (_v - _d) : 0;
    }

    function _enforceSeniorRatioCap(uint256 _v0, uint256 _d0, uint256 _assetsIn) internal view {
        if (maxSeniorRatioBps == 0) return;
        uint256 V1 = _v0 + _assetsIn;
        uint256 D1 = _d0 + _assetsIn;
        uint256 ratioBps = Math.mulDiv(D1, Constants.BPS, V1);
        if (ratioBps > maxSeniorRatioBps) revert MaxSeniorRatioExceeded();
    }

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
