// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ITrancheController} from "../interfaces/ITrancheController.sol";
import {ITrancheFactory} from "../interfaces/ITrancheFactory.sol";
import {ITrancheRegistry} from "../interfaces/ITrancheRegistry.sol";
import {ITrancheToken} from "../interfaces/ITrancheToken.sol";

/// @title Tranche Factory
/// @notice Deploys tranche controller/token clones and registers metadata in `TrancheRegistry`.
contract TrancheFactory is ITrancheFactory, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:storage-location erc7201:pontus.storage.TrancheFactory
    /// @notice EIP-7201 storage container for factory config.
    struct TrancheFactoryStorage {
        /// @notice Controller implementation used by `Clones.clone`.
        address controllerImpl;
        /// @notice Token implementation used by `Clones.clone`.
        address tokenImpl;
        /// @notice Registry that records created vault sets.
        address registry;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("pontus.storage.TrancheFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANCHE_FACTORY_STORAGE_LOCATION =
        0xb676ae5ac50bbb0e60b485f4f5242e5fd2a6ea6a85b2d6e7832f66c42d872b00;
    /// @dev Domain separator prefix for deterministic config hashing.
    bytes32 private constant TRANCHE_VAULT_PARAMS_HASH_PREFIX = keccak256("pontus.tranche.vault.params.v1");

    /// @notice Disables implementation initialization.
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheFactory
    function initialize(address _owner, address _controllerImpl, address _tokenImpl, address _registry)
        external
        override
        initializer
    {
        if (_owner == address(0)) revert ZeroAddress();
        if (_controllerImpl == address(0) || _tokenImpl == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        TrancheFactoryStorage storage $ = _getStorage();
        $.controllerImpl = _controllerImpl;
        $.tokenImpl = _tokenImpl;
        $.registry = _registry;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheFactory
    function setControllerImpl(address _newControllerImpl) external override onlyOwner {
        if (_newControllerImpl == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit ControllerImplementationUpdated($.controllerImpl, _newControllerImpl);
        $.controllerImpl = _newControllerImpl;
    }

    /// @inheritdoc ITrancheFactory
    function setTokenImpl(address _newTokenImpl) external override onlyOwner {
        if (_newTokenImpl == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit TokenImplementationUpdated($.tokenImpl, _newTokenImpl);
        $.tokenImpl = _newTokenImpl;
    }

    /// @inheritdoc ITrancheFactory
    function setRegistry(address _newRegistry) external override onlyOwner {
        if (_newRegistry == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit RegistryUpdated($.registry, _newRegistry);
        $.registry = _newRegistry;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheFactory
    function createTrancheVault(TrancheVaultConfig calldata _config)
        external
        override
        onlyOwner
        returns (bytes32 _paramsHash)
    {
        TrancheFactoryStorage storage $ = _getStorage();
        if ($.registry == address(0)) revert ZeroAddress();
        _paramsHash = _computeParamsHash(_config);

        address controller = Clones.clone($.controllerImpl);
        address seniorToken = Clones.clone($.tokenImpl);
        address juniorToken = Clones.clone($.tokenImpl);

        ITrancheToken(seniorToken)
            .initialize(_config.seniorName, _config.seniorSymbol, _config.tokenDecimals, controller);
        ITrancheToken(juniorToken)
            .initialize(_config.juniorName, _config.juniorSymbol, _config.tokenDecimals, controller);

        ITrancheController(controller)
            .initialize(
                ITrancheController.InitParams({
                    asset: _config.asset,
                    vault: _config.vault,
                    teller: _config.teller,
                    accountant: _config.accountant,
                    operator: _config.operator,
                    guardian: _config.guardian,
                    seniorToken: seniorToken,
                    juniorToken: juniorToken,
                    seniorRatePerSecondWad: _config.seniorRatePerSecondWad,
                    rateModel: _config.rateModel,
                    maxSeniorRatioBps: _config.maxSeniorRatioBps
                })
            );

        ITrancheRegistry($.registry)
            .registerTrancheVault(
                ITrancheRegistry.TrancheVaultInfo({
                    controller: controller,
                    seniorToken: seniorToken,
                    juniorToken: juniorToken,
                    vault: _config.vault,
                    teller: _config.teller,
                    accountant: _config.accountant,
                    manager: _config.manager,
                    asset: _config.asset,
                    paramsHash: _paramsHash
                })
            );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrancheFactory
    function computeParamsHash(TrancheVaultConfig calldata _config)
        external
        view
        override
        returns (bytes32 _paramsHash)
    {
        return _computeParamsHash(_config);
    }

    /// @inheritdoc ITrancheFactory
    function controllerImpl() public view override returns (address) {
        return _getStorage().controllerImpl;
    }

    /// @inheritdoc ITrancheFactory
    function tokenImpl() public view override returns (address) {
        return _getStorage().tokenImpl;
    }

    /// @inheritdoc ITrancheFactory
    function registry() public view override returns (address) {
        return _getStorage().registry;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Computes deterministic config hash including chain id domain separation.
    /// @param _config Vault config payload.
    /// @return _paramsHash Deterministic params hash.
    function _computeParamsHash(TrancheVaultConfig calldata _config) internal view returns (bytes32 _paramsHash) {
        return keccak256(abi.encode(TRANCHE_VAULT_PARAMS_HASH_PREFIX, block.chainid, _config));
    }

    /// @notice Returns pointer to EIP-7201 storage slot.
    /// @return $ Storage pointer.
    function _getStorage() private pure returns (TrancheFactoryStorage storage $) {
        assembly {
            $.slot := TRANCHE_FACTORY_STORAGE_LOCATION
        }
    }
}
