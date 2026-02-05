// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {AccessControl} from "../libraries/AccessControl.sol";
import {Initializable} from "../libraries/Initializable.sol";
import {Pausable} from "../libraries/Pausable.sol";
import {ReentrancyGuard} from "../libraries/ReentrancyGuard.sol";
import {MathUtils} from "../libraries/MathUtils.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";

import {IERC20Minimal} from "../interfaces/IERC20Minimal.sol";
import {IRateModel} from "../interfaces/IRateModel.sol";
import {ITeller} from "../interfaces/ITeller.sol";
import {ITrancheToken} from "../interfaces/ITrancheToken.sol";

contract TrancheController is AccessControl, Initializable, Pausable, ReentrancyGuard {
    using SafeTransferLib for IERC20Minimal;

    error ZeroAddress();
    error ZeroAmount();
    error ZeroValue();
    error UnderwaterJunior();
    error InvalidBps();
    error MaxSeniorRatioExceeded();

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    uint256 public constant WAD = 1e18;
    uint256 public constant BPS = 10_000;

    IERC20Minimal public asset;
    IERC20Minimal public vaultShares;
    ITeller public teller;
    ITrancheToken public seniorToken;
    ITrancheToken public juniorToken;

    uint256 public seniorDebt;
    uint256 public seniorRatePerSecondWad;
    address public rateModel;
    uint256 public lastAccrualTs;
    uint256 public maxSeniorRatioBps;
    address public vault;

    event Accrued(uint256 newSeniorDebt, uint256 dt);
    event SeniorRateUpdated(uint256 oldRate, uint256 newRate);
    event RateModelUpdated(address indexed oldModel, address indexed newModel);
    event TellerUpdated(address indexed oldTeller, address indexed newTeller);
    event MaxSeniorRatioUpdated(uint256 oldRatioBps, uint256 newRatioBps);

    event SeniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event JuniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event SeniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);
    event JuniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);

    function initialize(
        address asset_,
        address vault_,
        address teller_,
        address operator,
        address guardian,
        address seniorToken_,
        address juniorToken_,
        uint256 seniorRatePerSecondWad_,
        address rateModel_,
        uint256 maxSeniorRatioBps_
    ) external initializer {
        if (asset_ == address(0) || vault_ == address(0) || teller_ == address(0)) {
            revert ZeroAddress();
        }
        if (operator == address(0) || guardian == address(0)) revert ZeroAddress();
        if (seniorToken_ == address(0) || juniorToken_ == address(0)) revert ZeroAddress();
        if (maxSeniorRatioBps_ > BPS) revert InvalidBps();

        asset = IERC20Minimal(asset_);
        vault = vault_;
        vaultShares = IERC20Minimal(vault_);
        teller = ITeller(teller_);
        seniorToken = ITrancheToken(seniorToken_);
        juniorToken = ITrancheToken(juniorToken_);
        seniorRatePerSecondWad = seniorRatePerSecondWad_;
        rateModel = rateModel_;
        maxSeniorRatioBps = maxSeniorRatioBps_;
        lastAccrualTs = block.timestamp;

        _initReentrancyGuard();
        _grantRole(DEFAULT_ADMIN_ROLE, operator);
        _grantRole(OPERATOR_ROLE, operator);
        _grantRole(GUARDIAN_ROLE, guardian);
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
        teller = ITeller(newTeller);
    }

    function setMaxSeniorRatioBps(uint256 newRatioBps) external onlyRole(OPERATOR_ROLE) {
        if (newRatioBps > BPS) revert InvalidBps();
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

        uint256 interest = MathUtils.mulDivDown(D0, r * dt, WAD);
        seniorDebt = D0 + interest;
        emit Accrued(seniorDebt, dt);
    }

    function previewV() public view returns (uint256) {
        uint256 shares = vaultShares.balanceOf(address(this));
        if (shares == 0) return 0;
        return teller.previewRedeem(shares);
    }

    function previewDepositSenior(uint256 assetsIn) external view returns (uint256 sharesOut) {
        if (assetsIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        uint256 seniorValue0 = _seniorValue(V0, D0);

        if (S0 == 0) return assetsIn;
        if (seniorValue0 == 0) return 0;
        return MathUtils.mulDivDown(assetsIn, S0, seniorValue0);
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
        return MathUtils.mulDivDown(assetsIn, J0, juniorValue0);
    }

    function previewRedeemSenior(uint256 sharesIn) external view returns (uint256 assetsOut) {
        if (sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 S0 = seniorToken.totalSupply();
        if (S0 == 0) return 0;
        uint256 seniorValue0 = _seniorValue(V0, D0);
        return MathUtils.mulDivDown(sharesIn, seniorValue0, S0);
    }

    function previewRedeemJunior(uint256 sharesIn) external view returns (uint256 assetsOut) {
        if (sharesIn == 0) return 0;
        uint256 V0 = previewV();
        uint256 D0 = _previewDebt();
        uint256 J0 = juniorToken.totalSupply();
        if (J0 == 0) return 0;
        uint256 juniorValue0 = _juniorValue(V0, D0);
        return MathUtils.mulDivDown(sharesIn, juniorValue0, J0);
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
            sharesOut = MathUtils.mulDivDown(assetsIn, S0, seniorValue0);
        }

        _enforceSeniorRatioCap(V0, D0, assetsIn);

        asset.safeTransferFrom(msg.sender, address(this), assetsIn);
        asset.forceApprove(address(teller), assetsIn);
        teller.deposit(assetsIn, address(this));

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
            sharesOut = MathUtils.mulDivDown(assetsIn, J0, juniorValue0);
        }

        asset.safeTransferFrom(msg.sender, address(this), assetsIn);
        asset.forceApprove(address(teller), assetsIn);
        teller.deposit(assetsIn, address(this));

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
        assetsOut = MathUtils.mulDivDown(sharesIn, seniorValue0, S0);

        seniorToken.burnFrom(msg.sender, sharesIn);
        if (assetsOut != 0) {
            seniorDebt = D0 - assetsOut;
            teller.withdraw(assetsOut, receiver);
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
        assetsOut = MathUtils.mulDivDown(sharesIn, juniorValue0, J0);

        juniorToken.burnFrom(msg.sender, sharesIn);
        if (assetsOut != 0) {
            teller.withdraw(assetsOut, receiver);
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
        uint256 interest = MathUtils.mulDivDown(D0, r * dt, WAD);
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
        uint256 ratioBps = MathUtils.mulDivDown(D1, BPS, V1);
        if (ratioBps > maxSeniorRatioBps) revert MaxSeniorRatioExceeded();
    }
}
