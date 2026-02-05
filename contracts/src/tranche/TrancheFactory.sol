// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {TrancheController} from "./TrancheController.sol";
import {TrancheRegistry} from "./TrancheRegistry.sol";
import {TrancheToken} from "./TrancheToken.sol";

contract TrancheFactory is Ownable {
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

    constructor(address owner_, address controllerImpl_, address tokenImpl_, address registry_) Ownable(owner_) {
        if (controllerImpl_ == address(0) || tokenImpl_ == address(0)) revert ZeroAddress();
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

        TrancheToken(seniorToken)
            .initialize(config.seniorName, config.seniorSymbol, config.tokenDecimals, controller);
        TrancheToken(juniorToken)
            .initialize(config.juniorName, config.juniorSymbol, config.tokenDecimals, controller);

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

        productId = TrancheRegistry(registry)
            .registerProduct(
                TrancheRegistry.ProductInfo({
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
}
