// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITrancheRegistry} from "../interfaces/tranche/ITrancheRegistry.sol";

/// @title Tranche Registry
/// @author Kevin Lin (@kevinsslin)
/// @notice Persists tranche vault metadata keyed by params hash.
contract TrancheRegistry is ITrancheRegistry, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:storage-location erc7201:pontus.storage.TrancheRegistry
    /// @notice EIP-7201 storage container for registry data.
    struct TrancheRegistryStorage {
        /// @notice Authorized factory allowed to register new vault records.
        address factory;
        /// @notice Vault metadata keyed by deterministic params hash.
        mapping(bytes32 paramsHash => TrancheVaultInfo info) trancheVaultsByParamsHash;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("pontus.storage.TrancheRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANCHE_REGISTRY_STORAGE_LOCATION =
        0x8e5d8f9d12f75b408e3765ef5743b79724b9415f249c865effeedac3a7fbcc00;

    /// @notice Disables implementation initialization.
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts caller to configured factory.
    modifier onlyFactory() {
        if (msg.sender != factory()) revert NotFactory();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheRegistry
    function initialize(address _owner, address _factory) external override initializer {
        if (_owner == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        _getStorage().factory = _factory;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheRegistry
    function setFactory(address _newFactory) external override onlyOwner {
        if (_newFactory == address(0)) revert ZeroAddress();
        TrancheRegistryStorage storage $ = _getStorage();
        emit FactoryUpdated($.factory, _newFactory);
        $.factory = _newFactory;
    }

    /*//////////////////////////////////////////////////////////////
                           FACTORY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheRegistry
    function registerTrancheVault(TrancheVaultInfo calldata _info)
        external
        override
        onlyFactory
        returns (bytes32 _paramsHash)
    {
        _assertValidTrancheVaultInfo(_info);
        TrancheRegistryStorage storage $ = _getStorage();
        _paramsHash = _info.paramsHash;
        // `controller` is guaranteed non-zero for valid records and doubles as existence sentinel.
        if ($.trancheVaultsByParamsHash[_paramsHash].controller != address(0)) {
            revert TrancheVaultAlreadyRegistered(_paramsHash);
        }

        $.trancheVaultsByParamsHash[_paramsHash] = _info;
        emit TrancheVaultCreated(
            _paramsHash,
            _info.controller,
            _info.seniorToken,
            _info.juniorToken,
            _info.vault,
            _info.teller,
            _info.accountant,
            _info.manager,
            _info.asset
        );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheRegistry
    function trancheVaultByParamsHash(bytes32 _paramsHash)
        external
        view
        override
        returns (TrancheVaultInfo memory _info)
    {
        _info = _getStorage().trancheVaultsByParamsHash[_paramsHash];
        if (_info.controller == address(0)) revert TrancheVaultNotFound(_paramsHash);
    }

    /// @inheritdoc ITrancheRegistry
    function trancheVaultExists(bytes32 _paramsHash) external view override returns (bool _exists) {
        return _getStorage().trancheVaultsByParamsHash[_paramsHash].controller != address(0);
    }

    /// @inheritdoc ITrancheRegistry
    function factory() public view override returns (address) {
        return _getStorage().factory;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Ensures all required vault metadata fields are non-zero.
    /// @param _info Vault metadata to validate.
    function _assertValidTrancheVaultInfo(TrancheVaultInfo calldata _info) private pure {
        if (_info.controller == address(0)) revert ZeroAddress();
        if (_info.seniorToken == address(0)) revert ZeroAddress();
        if (_info.juniorToken == address(0)) revert ZeroAddress();
        if (_info.vault == address(0)) revert ZeroAddress();
        if (_info.teller == address(0)) revert ZeroAddress();
        if (_info.accountant == address(0)) revert ZeroAddress();
        if (_info.manager == address(0)) revert ZeroAddress();
        if (_info.asset == address(0)) revert ZeroAddress();
    }

    /// @notice Returns pointer to EIP-7201 storage slot.
    /// @return $ Storage pointer.
    function _getStorage() private pure returns (TrancheRegistryStorage storage $) {
        assembly {
            $.slot := TRANCHE_REGISTRY_STORAGE_LOCATION
        }
    }
}
