// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccountantWithRateProviders} from "../../lib/boring-vault/src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "../../lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ITrancheToken} from "./ITrancheToken.sol";

interface ITrancheController {
    error ZeroAddress();
    error ZeroAmount();
    error ZeroValue();
    error UnderwaterJunior();
    error InvalidBps();
    error MaxSeniorRatioExceeded();

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

    event Accrued(uint256 newSeniorDebt, uint256 dt);
    event SeniorRateUpdated(uint256 oldRate, uint256 newRate);
    event RateModelUpdated(address indexed oldModel, address indexed newModel);
    event TellerUpdated(address indexed oldTeller, address indexed newTeller);
    event MaxSeniorRatioUpdated(uint256 oldRatioBps, uint256 newRatioBps);
    event SeniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event JuniorDeposited(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event SeniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);
    event JuniorRedeemed(address indexed caller, address indexed receiver, uint256 shares, uint256 assets);

    function OPERATOR_ROLE() external view returns (bytes32);
    function GUARDIAN_ROLE() external view returns (bytes32);

    function asset() external view returns (IERC20);
    function accountant() external view returns (AccountantWithRateProviders);
    function teller() external view returns (TellerWithMultiAssetSupport);
    function seniorToken() external view returns (ITrancheToken);
    function juniorToken() external view returns (ITrancheToken);

    function seniorDebt() external view returns (uint256);
    function seniorRatePerSecondWad() external view returns (uint256);
    function rateModel() external view returns (address);
    function lastAccrualTs() external view returns (uint256);
    function maxSeniorRatioBps() external view returns (uint256);
    function vault() external view returns (address);
    function oneShare() external view returns (uint256);

    function initialize(InitParams calldata _params) external;
    function pause() external;
    function unpause() external;
    function setSeniorRatePerSecondWad(uint256 _newRate) external;
    function setRateModel(address _newRateModel) external;
    function setTeller(address _newTeller) external;
    function setMaxSeniorRatioBps(uint256 _newRatioBps) external;

    function accrue() external;
    function previewV() external view returns (uint256);
    function previewDepositSenior(uint256 _assetsIn) external view returns (uint256 _sharesOut);
    function previewDepositJunior(uint256 _assetsIn) external view returns (uint256 _sharesOut);
    function previewRedeemSenior(uint256 _sharesIn) external view returns (uint256 _assetsOut);
    function previewRedeemJunior(uint256 _sharesIn) external view returns (uint256 _assetsOut);

    function depositSenior(uint256 _assetsIn, address _receiver) external returns (uint256 _sharesOut);
    function depositJunior(uint256 _assetsIn, address _receiver) external returns (uint256 _sharesOut);
    function redeemSenior(uint256 _sharesIn, address _receiver) external returns (uint256 _assetsOut);
    function redeemJunior(uint256 _sharesIn, address _receiver) external returns (uint256 _assetsOut);
}
