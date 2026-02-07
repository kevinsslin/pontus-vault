// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IRateModel} from "../interfaces/IRateModel.sol";
import {IRefRateProvider} from "../interfaces/IRefRateProvider.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CapSafetyRateModel is IRateModel, Ownable {
    error InvalidSafetyFactor();

    uint256 public capRatePerSecondWad;
    uint256 public safetyFactorWad;
    address public refRateProvider;

    event CapRateUpdated(uint256 oldCap, uint256 newCap);
    event SafetyFactorUpdated(uint256 oldFactor, uint256 newFactor);
    event RefRateProviderUpdated(address indexed oldProvider, address indexed newProvider);

    constructor(address _owner, address _refRateProvider, uint256 _capRatePerSecondWad, uint256 _safetyFactorWad)
        Ownable(_owner)
    {
        _setRefRateProvider(_refRateProvider);
        _setCapRate(_capRatePerSecondWad);
        _setSafetyFactor(_safetyFactorWad);
    }

    /*//////////////////////////////////////////////////////////////
                           OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setCapRatePerSecondWad(uint256 _newCap) external onlyOwner {
        _setCapRate(_newCap);
    }

    function setSafetyFactorWad(uint256 _newFactor) external onlyOwner {
        _setSafetyFactor(_newFactor);
    }

    function setRefRateProvider(address _newProvider) external onlyOwner {
        _setRefRateProvider(_newProvider);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRatePerSecondWad() external view returns (uint256) {
        if (refRateProvider == address(0)) {
            return 0;
        }

        uint256 refRate = IRefRateProvider(refRateProvider).getRatePerSecondWad();
        uint256 adjusted = Math.mulDiv(refRate, safetyFactorWad, 1e18);
        return adjusted < capRatePerSecondWad ? adjusted : capRatePerSecondWad;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setCapRate(uint256 _newCap) internal {
        emit CapRateUpdated(capRatePerSecondWad, _newCap);
        capRatePerSecondWad = _newCap;
    }

    function _setSafetyFactor(uint256 _newFactor) internal {
        if (_newFactor > 1e18) revert InvalidSafetyFactor();
        emit SafetyFactorUpdated(safetyFactorWad, _newFactor);
        safetyFactorWad = _newFactor;
    }

    function _setRefRateProvider(address _newProvider) internal {
        emit RefRateProviderUpdated(refRateProvider, _newProvider);
        refRateProvider = _newProvider;
    }
}
