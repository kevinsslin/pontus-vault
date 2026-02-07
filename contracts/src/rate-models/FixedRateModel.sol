// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRateModel} from "../interfaces/IRateModel.sol";

/// @title Fixed Rate Model
/// @notice Returns a manually managed constant per-second WAD rate.
contract FixedRateModel is IRateModel, Ownable {
    /// @notice Reserved error for zero-rate validation.
    error ZeroRate();

    /// @notice Configured per-second WAD rate.
    uint256 public ratePerSecondWad;

    /// @notice Emitted when fixed rate is updated.
    /// @param oldRate Previous rate.
    /// @param newRate New rate.
    event RateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Initializes fixed rate model.
    /// @param _owner Contract owner.
    /// @param _ratePerSecondWad Initial per-second WAD rate.
    constructor(address _owner, uint256 _ratePerSecondWad) Ownable(_owner) {
        ratePerSecondWad = _ratePerSecondWad;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates fixed rate value.
    /// @param _newRate New per-second WAD rate.
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
