// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Owned {
    error NotOwner();
    error ZeroOwner();

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function _initOwner(address newOwner) internal {
        if (newOwner == address(0)) revert ZeroOwner();
        owner = newOwner;
        emit OwnershipTransferred(address(0), newOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
