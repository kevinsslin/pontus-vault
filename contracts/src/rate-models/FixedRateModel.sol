// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IFixedRateModel} from "../interfaces/rates/IFixedRateModel.sol";
import {IRateModel} from "../interfaces/rates/IRateModel.sol";

/// @title Fixed Rate Model
/// @author Kevin Lin (@kevinsslin)
/// @notice Returns a manually managed constant per-second WAD rate.
contract FixedRateModel is IFixedRateModel, Ownable {
    /// @notice Configured per-second WAD rate.
    uint256 public ratePerSecondWad;

    /// @notice Initializes fixed rate model.
    /// @param _owner Contract owner.
    /// @param _ratePerSecondWad Initial per-second WAD rate.
    constructor(address _owner, uint256 _ratePerSecondWad) Ownable(_owner) {
        ratePerSecondWad = _ratePerSecondWad;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFixedRateModel
    function setRatePerSecondWad(uint256 _newRate) external onlyOwner {
        emit RateUpdated(ratePerSecondWad, _newRate);
        ratePerSecondWad = _newRate;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRateModel
    function getRatePerSecondWad() external view returns (uint256) {
        return ratePerSecondWad;
    }
}
