// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AccountantWithRateProviders} from "../../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";

import {ITrancheToken} from "./ITrancheToken.sol";

/// @title Tranche Controller Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Coordinates senior/junior deposits, redemptions, and senior debt accrual.
interface ITrancheController {
    /// @notice Emitted when an address argument is zero.
    error ZeroAddress();
    /// @notice Emitted when an amount argument is zero.
    error ZeroAmount();
    /// @notice Emitted when a valuation-based operation resolves to zero value.
    error ZeroValue();
    /// @notice Emitted when junior-side action requires positive junior equity but vault is underwater.
    error UnderwaterJunior();
    /// @notice Emitted when a basis points value exceeds `Constants.BPS`.
    error InvalidBps();
    /// @notice Emitted when post-deposit senior ratio exceeds configured cap.
    error MaxSeniorRatioExceeded();

    /// @notice Initialization parameters for a controller instance.
    struct InitParams {
        /// @notice Underlying ERC20 asset.
        address asset;
        /// @notice BoringVault share token address.
        address vault;
        /// @notice BoringVault teller contract.
        address teller;
        /// @notice BoringVault accountant contract.
        address accountant;
        /// @notice Operator/admin role for configuration updates.
        address operator;
        /// @notice Guardian role for pause controls.
        address guardian;
        /// @notice Senior tranche token.
        address seniorToken;
        /// @notice Junior tranche token.
        address juniorToken;
        /// @notice Static fallback senior rate in per-second WAD.
        uint256 seniorRatePerSecondWad;
        /// @notice Optional external rate model address.
        address rateModel;
        /// @notice Maximum allowed senior debt ratio in bps.
        uint256 maxSeniorRatioBps;
    }

    /// @notice Emitted after debt accrual.
    /// @param newSeniorDebt Updated senior debt after accrual.
    /// @param dt Elapsed seconds accrued.
    event Accrued(uint256 newSeniorDebt, uint256 dt);
    /// @notice Emitted when static senior rate is updated.
    /// @param oldRate Previous per-second WAD rate.
    /// @param newRate New per-second WAD rate.
    event SeniorRateUpdated(uint256 oldRate, uint256 newRate);
    /// @notice Emitted when dynamic rate model is updated.
    /// @param oldModel Previous rate model.
    /// @param newModel New rate model.
    event RateModelUpdated(address indexed oldModel, address indexed newModel);
    /// @notice Emitted when teller address is updated.
    /// @param oldTeller Previous teller address.
    /// @param newTeller New teller address.
    event TellerUpdated(address indexed oldTeller, address indexed newTeller);
    /// @notice Emitted when senior ratio cap is updated.
    /// @param oldRatioBps Previous cap in bps.
    /// @param newRatioBps New cap in bps.
    event MaxSeniorRatioUpdated(uint256 oldRatioBps, uint256 newRatioBps);
    /// @notice Emitted on senior deposit.
    /// @param caller Caller address.
    /// @param receiver Receiver of minted shares.
    /// @param assets Asset amount deposited.
    /// @param shares Share amount minted.
    event SeniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    /// @notice Emitted on junior deposit.
    /// @param caller Caller address.
    /// @param receiver Receiver of minted shares.
    /// @param assets Asset amount deposited.
    /// @param shares Share amount minted.
    event JuniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    /// @notice Emitted on senior redemption.
    /// @param caller Caller address.
    /// @param receiver Receiver of returned assets.
    /// @param shares Share amount burned.
    /// @param assets Asset amount returned.
    event SeniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);
    /// @notice Emitted on junior redemption.
    /// @param caller Caller address.
    /// @param receiver Receiver of returned assets.
    /// @param shares Share amount burned.
    /// @param assets Asset amount returned.
    event JuniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);

    /// @notice Returns role identifier for operator actions.
    /// @return _operatorRole Role id.
    function OPERATOR_ROLE() external view returns (bytes32);
    /// @notice Returns role identifier for guardian pause actions.
    /// @return _guardianRole Role id.
    function GUARDIAN_ROLE() external view returns (bytes32);

    /// @notice Returns underlying asset token.
    /// @return _asset Asset token interface.
    function asset() external view returns (IERC20);
    /// @notice Returns accountant role contract.
    /// @return _accountant Accountant contract.
    function accountant() external view returns (AccountantWithRateProviders);
    /// @notice Returns teller role contract.
    /// @return _teller Teller contract.
    function teller() external view returns (TellerWithMultiAssetSupport);
    /// @notice Returns senior tranche token.
    /// @return _seniorToken Senior token.
    function seniorToken() external view returns (ITrancheToken);
    /// @notice Returns junior tranche token.
    /// @return _juniorToken Junior token.
    function juniorToken() external view returns (ITrancheToken);

    /// @notice Returns current accrued senior debt.
    /// @return _seniorDebt Debt in underlying asset units.
    function seniorDebt() external view returns (uint256);
    /// @notice Returns static per-second WAD senior rate.
    /// @return _seniorRatePerSecondWad Rate value.
    function seniorRatePerSecondWad() external view returns (uint256);
    /// @notice Returns configured external rate model.
    /// @return _rateModel Rate model contract address.
    function rateModel() external view returns (address);
    /// @notice Returns last accrual timestamp.
    /// @return _lastAccrualTs Unix timestamp.
    function lastAccrualTs() external view returns (uint256);
    /// @notice Returns configured maximum senior ratio cap in bps.
    /// @return _maxSeniorRatioBps Ratio cap.
    function maxSeniorRatioBps() external view returns (uint256);
    /// @notice Returns vault share token address.
    /// @return _vault BoringVault address.
    function vault() external view returns (address);
    /// @notice Returns one whole share unit for `vault` decimals.
    /// @return _oneShare Unit scalar.
    function oneShare() external view returns (uint256);

    /// @notice Initializes controller state and grants roles.
    /// @param _params Initialization parameter bundle.
    function initialize(InitParams calldata _params) external;
    /// @notice Pauses user deposit/redeem operations.
    function pause() external;
    /// @notice Unpauses user deposit/redeem operations.
    function unpause() external;
    /// @notice Updates static fallback senior rate.
    /// @param _newRate New per-second WAD rate.
    function setSeniorRatePerSecondWad(uint256 _newRate) external;
    /// @notice Updates dynamic rate model.
    /// @param _newRateModel New rate model address.
    function setRateModel(address _newRateModel) external;
    /// @notice Updates teller contract.
    /// @param _newTeller New teller address.
    function setTeller(address _newTeller) external;
    /// @notice Updates maximum senior ratio cap.
    /// @param _newRatioBps New ratio cap in basis points.
    function setMaxSeniorRatioBps(uint256 _newRatioBps) external;

    /// @notice Accrues senior debt from elapsed time and active rate.
    function accrue() external;
    /// @notice Returns current total vault asset value represented by held shares.
    /// @return _value Asset value in underlying units.
    function previewV() external view returns (uint256);
    /// @notice Previews minted senior shares for an asset deposit.
    /// @param _assetsIn Asset amount to deposit.
    /// @return _sharesOut Estimated shares minted.
    function previewDepositSenior(uint256 _assetsIn) external view returns (uint256 _sharesOut);
    /// @notice Previews minted junior shares for an asset deposit.
    /// @param _assetsIn Asset amount to deposit.
    /// @return _sharesOut Estimated shares minted.
    function previewDepositJunior(uint256 _assetsIn) external view returns (uint256 _sharesOut);
    /// @notice Previews returned assets for redeeming senior shares.
    /// @param _sharesIn Share amount to redeem.
    /// @return _assetsOut Estimated assets returned.
    function previewRedeemSenior(uint256 _sharesIn) external view returns (uint256 _assetsOut);
    /// @notice Previews returned assets for redeeming junior shares.
    /// @param _sharesIn Share amount to redeem.
    /// @return _assetsOut Estimated assets returned.
    function previewRedeemJunior(uint256 _sharesIn) external view returns (uint256 _assetsOut);

    /// @notice Deposits assets into the senior tranche.
    /// @param _assetsIn Asset amount to deposit.
    /// @param _receiver Receiver of minted senior shares.
    /// @return _sharesOut Shares minted.
    function depositSenior(uint256 _assetsIn, address _receiver) external returns (uint256 _sharesOut);
    /// @notice Deposits assets into the junior tranche.
    /// @param _assetsIn Asset amount to deposit.
    /// @param _receiver Receiver of minted junior shares.
    /// @return _sharesOut Shares minted.
    function depositJunior(uint256 _assetsIn, address _receiver) external returns (uint256 _sharesOut);
    /// @notice Redeems senior shares for underlying assets.
    /// @param _sharesIn Senior shares to burn.
    /// @param _receiver Receiver of redeemed assets.
    /// @return _assetsOut Assets redeemed.
    function redeemSenior(uint256 _sharesIn, address _receiver) external returns (uint256 _assetsOut);
    /// @notice Redeems junior shares for underlying assets.
    /// @param _sharesIn Junior shares to burn.
    /// @param _receiver Receiver of redeemed assets.
    /// @return _assetsOut Assets redeemed.
    function redeemJunior(uint256 _sharesIn, address _receiver) external returns (uint256 _assetsOut);
}
