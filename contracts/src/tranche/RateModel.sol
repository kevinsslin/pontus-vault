// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IRateModel} from "../interfaces/IRateModel.sol";
import {IRefRateProvider} from "../interfaces/IRefRateProvider.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FixedRateModel is IRateModel, Ownable {
    error ZeroRate();

    uint256 public ratePerSecondWad;

    event RateUpdated(uint256 oldRate, uint256 newRate);

    constructor(address owner_, uint256 ratePerSecondWad_) Ownable(owner_) {
        ratePerSecondWad = ratePerSecondWad_;
    }

    function setRatePerSecondWad(uint256 newRate) external onlyOwner {
        emit RateUpdated(ratePerSecondWad, newRate);
        ratePerSecondWad = newRate;
    }

    function getRatePerSecondWad() external view returns (uint256) {
        return ratePerSecondWad;
    }
}

contract CapSafetyRateModel is IRateModel, Ownable {
    error InvalidSafetyFactor();

    uint256 public capRatePerSecondWad;
    uint256 public safetyFactorWad;
    address public refRateProvider;

    event CapRateUpdated(uint256 oldCap, uint256 newCap);
    event SafetyFactorUpdated(uint256 oldFactor, uint256 newFactor);
    event RefRateProviderUpdated(address indexed oldProvider, address indexed newProvider);

    constructor(address owner_, address refRateProvider_, uint256 capRatePerSecondWad_, uint256 safetyFactorWad_)
        Ownable(owner_)
    {
        _setRefRateProvider(refRateProvider_);
        _setCapRate(capRatePerSecondWad_);
        _setSafetyFactor(safetyFactorWad_);
    }

    function setCapRatePerSecondWad(uint256 newCap) external onlyOwner {
        _setCapRate(newCap);
    }

    function setSafetyFactorWad(uint256 newFactor) external onlyOwner {
        _setSafetyFactor(newFactor);
    }

    function setRefRateProvider(address newProvider) external onlyOwner {
        _setRefRateProvider(newProvider);
    }

    function getRatePerSecondWad() external view returns (uint256) {
        if (refRateProvider == address(0)) {
            return 0;
        }
        uint256 refRate = IRefRateProvider(refRateProvider).getRatePerSecondWad();
        uint256 adjusted = Math.mulDiv(refRate, safetyFactorWad, 1e18);
        return adjusted < capRatePerSecondWad ? adjusted : capRatePerSecondWad;
    }

    function _setCapRate(uint256 newCap) internal {
        emit CapRateUpdated(capRatePerSecondWad, newCap);
        capRatePerSecondWad = newCap;
    }

    function _setSafetyFactor(uint256 newFactor) internal {
        if (newFactor > 1e18) revert InvalidSafetyFactor();
        emit SafetyFactorUpdated(safetyFactorWad, newFactor);
        safetyFactorWad = newFactor;
    }

    function _setRefRateProvider(address newProvider) internal {
        emit RefRateProviderUpdated(refRateProvider, newProvider);
        refRateProvider = newProvider;
    }
}
