// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Initializable {
    error AlreadyInitialized();

    bool private _initialized;

    modifier initializer() {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        _;
    }

    function _isInitialized() internal view returns (bool) {
        return _initialized;
    }
}
