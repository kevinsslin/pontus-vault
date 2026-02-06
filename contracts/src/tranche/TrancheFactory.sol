// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {TrancheController} from "./TrancheController.sol";
import {TrancheRegistry} from "./TrancheRegistry.sol";
import {TrancheToken} from "./TrancheToken.sol";

contract TrancheFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    error ZeroAddress();

    /// @custom:storage-location erc7201:pontus.storage.TrancheFactory
    struct TrancheFactoryStorage {
        address controllerImpl;
        address tokenImpl;
        address registry;
    }

    // keccak256(abi.encode(uint256(keccak256("pontus.storage.TrancheFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANCHE_FACTORY_STORAGE_LOCATION =
        0xb676ae5ac50bbb0e60b485f4f5242e5fd2a6ea6a85b2d6e7832f66c42d872b00;

    event ControllerImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event TokenImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    struct TrancheVaultConfig {
        bytes32 paramsHash;
        address asset;
        address vault;
        address teller;
        address accountant;
        address manager;
        address operator;
        address guardian;
        uint8 tokenDecimals;
        uint256 seniorRatePerSecondWad;
        address rateModel;
        uint256 maxSeniorRatioBps;
        string seniorName;
        string seniorSymbol;
        string juniorName;
        string juniorSymbol;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address controllerImpl_, address tokenImpl_, address registry_)
        external
        initializer
    {
        if (owner_ == address(0)) revert ZeroAddress();
        if (controllerImpl_ == address(0) || tokenImpl_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        TrancheFactoryStorage storage $ = _getStorage();
        $.controllerImpl = controllerImpl_;
        $.tokenImpl = tokenImpl_;
        $.registry = registry_;
    }

    function controllerImpl() public view returns (address) {
        return _getStorage().controllerImpl;
    }

    function tokenImpl() public view returns (address) {
        return _getStorage().tokenImpl;
    }

    function registry() public view returns (address) {
        return _getStorage().registry;
    }

    function setControllerImpl(address newControllerImpl) external onlyOwner {
        if (newControllerImpl == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit ControllerImplementationUpdated($.controllerImpl, newControllerImpl);
        $.controllerImpl = newControllerImpl;
    }

    function setTokenImpl(address newTokenImpl) external onlyOwner {
        if (newTokenImpl == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit TokenImplementationUpdated($.tokenImpl, newTokenImpl);
        $.tokenImpl = newTokenImpl;
    }

    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == address(0)) revert ZeroAddress();
        TrancheFactoryStorage storage $ = _getStorage();
        emit RegistryUpdated($.registry, newRegistry);
        $.registry = newRegistry;
    }

    function createTrancheVault(TrancheVaultConfig calldata config) external onlyOwner returns (uint256 vaultId) {
        TrancheFactoryStorage storage $ = _getStorage();
        if ($.registry == address(0)) revert ZeroAddress();

        address controller = Clones.clone($.controllerImpl);
        address seniorToken = Clones.clone($.tokenImpl);
        address juniorToken = Clones.clone($.tokenImpl);

        TrancheToken(seniorToken).initialize(config.seniorName, config.seniorSymbol, config.tokenDecimals, controller);
        TrancheToken(juniorToken).initialize(config.juniorName, config.juniorSymbol, config.tokenDecimals, controller);

        TrancheController(controller)
            .initialize(
                TrancheController.InitParams({
                    asset: config.asset,
                    vault: config.vault,
                    teller: config.teller,
                    accountant: config.accountant,
                    operator: config.operator,
                    guardian: config.guardian,
                    seniorToken: seniorToken,
                    juniorToken: juniorToken,
                    seniorRatePerSecondWad: config.seniorRatePerSecondWad,
                    rateModel: config.rateModel,
                    maxSeniorRatioBps: config.maxSeniorRatioBps
                })
            );

        vaultId = TrancheRegistry($.registry)
            .registerTrancheVault(
                TrancheRegistry.TrancheVaultInfo({
                    controller: controller,
                    seniorToken: seniorToken,
                    juniorToken: juniorToken,
                    vault: config.vault,
                    teller: config.teller,
                    accountant: config.accountant,
                    manager: config.manager,
                    asset: config.asset,
                    paramsHash: config.paramsHash
                })
            );
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _getStorage() private pure returns (TrancheFactoryStorage storage $) {
        assembly {
            $.slot := TRANCHE_FACTORY_STORAGE_LOCATION
        }
    }
}
