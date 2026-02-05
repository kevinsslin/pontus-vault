// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract ReentrancyGuard {
    error Reentrancy();

    uint256 private _status;

    function _initReentrancyGuard() internal {
        _status = 1;
    }

    modifier nonReentrant() {
        if (_status == 2) revert Reentrancy();
        _status = 2;
        _;
        _status = 1;
    }
}
