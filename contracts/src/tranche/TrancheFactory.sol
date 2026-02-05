// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Owned} from "../libraries/Owned.sol";
import {Clones} from "../libraries/Clones.sol";

interface ITrancheControllerInit {
    function initialize(
        address asset,
        address vault,
        address teller,
        address operator,
        address guardian,
        address seniorToken,
        address juniorToken,
        uint256 seniorRatePerSecondWad,
        address rateModel,
        uint256 maxSeniorRatioBps
    ) external;
}

interface ITrancheTokenInit {
    function initialize(string calldata name, string calldata symbol, uint8 decimals, address controller) external;
}

interface ITrancheRegistry {
    struct ProductInfo {
        address controller;
        address seniorToken;
        address juniorToken;
        address vault;
        address teller;
        address manager;
        address asset;
        bytes32 paramsHash;
    }

    function registerProduct(ProductInfo calldata info) external returns (uint256 productId);
}

contract TrancheFactory is Owned {
    error ZeroAddress();

    address public immutable controllerImpl;
    address public immutable tokenImpl;
    address public registry;

    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    struct ProductConfig {
        bytes32 paramsHash;
        address asset;
        address vault;
        address teller;
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

    constructor(address owner_, address controllerImpl_, address tokenImpl_, address registry_) {
        if (controllerImpl_ == address(0) || tokenImpl_ == address(0)) revert ZeroAddress();
        _initOwner(owner_);
        controllerImpl = controllerImpl_;
        tokenImpl = tokenImpl_;
        registry = registry_;
    }

    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == address(0)) revert ZeroAddress();
        emit RegistryUpdated(registry, newRegistry);
        registry = newRegistry;
    }

    function createProduct(ProductConfig calldata config) external onlyOwner returns (uint256 productId) {
        if (registry == address(0)) revert ZeroAddress();

        address controller = Clones.clone(controllerImpl);
        address seniorToken = Clones.clone(tokenImpl);
        address juniorToken = Clones.clone(tokenImpl);

        ITrancheTokenInit(seniorToken)
            .initialize(config.seniorName, config.seniorSymbol, config.tokenDecimals, controller);
        ITrancheTokenInit(juniorToken)
            .initialize(config.juniorName, config.juniorSymbol, config.tokenDecimals, controller);

        ITrancheControllerInit(controller)
            .initialize(
                config.asset,
                config.vault,
                config.teller,
                config.operator,
                config.guardian,
                seniorToken,
                juniorToken,
                config.seniorRatePerSecondWad,
                config.rateModel,
                config.maxSeniorRatioBps
            );

        productId = ITrancheRegistry(registry)
            .registerProduct(
                ITrancheRegistry.ProductInfo({
                    controller: controller,
                    seniorToken: seniorToken,
                    juniorToken: juniorToken,
                    vault: config.vault,
                    teller: config.teller,
                    manager: config.manager,
                    asset: config.asset,
                    paramsHash: config.paramsHash
                })
            );
    }
}
