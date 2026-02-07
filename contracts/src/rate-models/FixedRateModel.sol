// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRateModel} from "../interfaces/IRateModel.sol";

contract FixedRateModel is IRateModel, Ownable {
    error ZeroRate();

    uint256 public ratePerSecondWad;

    event RateUpdated(uint256 oldRate, uint256 newRate);

    constructor(address _owner, uint256 _ratePerSecondWad) Ownable(_owner) {
        ratePerSecondWad = _ratePerSecondWad;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRatePerSecondWad(uint256 _newRate) external onlyOwner {
        emit RateUpdated(ratePerSecondWad, _newRate);
        ratePerSecondWad = _newRate;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRatePerSecondWad() external view returns (uint256) {
        return ratePerSecondWad;
    }
}
