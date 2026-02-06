// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TrancheRegistry is Initializable, OwnableUpgradeable, UUPSUpgradeable {
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

    /// @custom:storage-location erc7201:pontus.storage.TrancheRegistry
    struct TrancheRegistryStorage {
        address factory;
        TrancheVaultInfo[] trancheVaults;
    }

    // keccak256(abi.encode(uint256(keccak256("pontus.storage.TrancheRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANCHE_REGISTRY_STORAGE_LOCATION =
        0x8e5d8f9d12f75b408e3765ef5743b79724b9415f249c865effeedac3a7fbcc00;

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

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address factory_) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        _getStorage().factory = factory_;
    }

    modifier onlyFactory() {
        if (msg.sender != factory()) revert NotFactory();
        _;
    }

    function factory() public view returns (address) {
        return _getStorage().factory;
    }

    function setFactory(address newFactory) external onlyOwner {
        if (newFactory == address(0)) revert ZeroAddress();
        TrancheRegistryStorage storage $ = _getStorage();
        emit FactoryUpdated($.factory, newFactory);
        $.factory = newFactory;
    }

    function registerTrancheVault(TrancheVaultInfo calldata info) external onlyFactory returns (uint256 vaultId) {
        TrancheRegistryStorage storage $ = _getStorage();
        vaultId = $.trancheVaults.length;
        $.trancheVaults.push(info);
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
        return _getStorage().trancheVaults.length;
    }

    function trancheVaults(uint256 id) external view returns (TrancheVaultInfo memory) {
        return _getStorage().trancheVaults[id];
    }

    function getTrancheVaults(uint256 offset, uint256 limit) external view returns (TrancheVaultInfo[] memory) {
        TrancheRegistryStorage storage $ = _getStorage();
        uint256 total = $.trancheVaults.length;
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
            page[i] = $.trancheVaults[offset + i];
        }
        return page;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _getStorage() private pure returns (TrancheRegistryStorage storage $) {
        assembly {
            $.slot := TRANCHE_REGISTRY_STORAGE_LOCATION
        }
    }
}
