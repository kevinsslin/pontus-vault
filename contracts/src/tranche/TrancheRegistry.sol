// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TrancheRegistry is Ownable {
    error NotFactory();
    error ZeroAddress();

    struct TrancheVaultInfo {
        address controller;
        address seniorToken;
        address juniorToken;
        address vault;
        address teller;
        address accountant;
        address manager;
        address asset;
        bytes32 paramsHash;
    }

    address public factory;
    TrancheVaultInfo[] private _trancheVaults;

    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);
    event TrancheVaultCreated(
        uint256 indexed vaultId,
        address indexed controller,
        address seniorToken,
        address juniorToken,
        address indexed vault,
        address teller,
        address accountant,
        address manager,
        address asset,
        bytes32 paramsHash
    );

    constructor(address owner_, address factory_) Ownable(owner_) {
        factory = factory_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    function setFactory(address newFactory) external onlyOwner {
        if (newFactory == address(0)) revert ZeroAddress();
        emit FactoryUpdated(factory, newFactory);
        factory = newFactory;
    }

    function registerTrancheVault(TrancheVaultInfo calldata info) external onlyFactory returns (uint256 vaultId) {
        vaultId = _trancheVaults.length;
        _trancheVaults.push(info);
        emit TrancheVaultCreated(
            vaultId,
            info.controller,
            info.seniorToken,
            info.juniorToken,
            info.vault,
            info.teller,
            info.accountant,
            info.manager,
            info.asset,
            info.paramsHash
        );
    }

    function trancheVaultCount() external view returns (uint256) {
        return _trancheVaults.length;
    }

    function trancheVaults(uint256 id) external view returns (TrancheVaultInfo memory) {
        return _trancheVaults[id];
    }

    function getTrancheVaults(uint256 offset, uint256 limit) external view returns (TrancheVaultInfo[] memory) {
        uint256 total = _trancheVaults.length;
        if (offset >= total) {
            return new TrancheVaultInfo[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        uint256 size = end - offset;
        TrancheVaultInfo[] memory page = new TrancheVaultInfo[](size);
        for (uint256 i = 0; i < size; i++) {
            page[i] = _trancheVaults[offset + i];
        }
        return page;
    }
}
