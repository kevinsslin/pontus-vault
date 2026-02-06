// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseScript} from "./BaseScript.sol";
import {TrancheController} from "../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../src/tranche/TrancheFactory.sol";
import {TrancheRegistry} from "../src/tranche/TrancheRegistry.sol";
import {TrancheToken} from "../src/tranche/TrancheToken.sol";

contract DeployInfra is BaseScript {
    function run() public {
        uint256 deployerKey = _envUint("PRIVATE_KEY", 0);
        require(deployerKey != 0, "PRIVATE_KEY missing");

        address owner = _envAddress("OWNER", vm.addr(deployerKey));

        vm.startBroadcast(deployerKey);

        TrancheController controllerImpl = new TrancheController();
        TrancheToken tokenImpl = new TrancheToken();
        TrancheRegistry registryImpl = new TrancheRegistry();
        TrancheFactory factoryImpl = new TrancheFactory();

        TrancheRegistry registry = TrancheRegistry(
            address(
                new ERC1967Proxy(address(registryImpl), abi.encodeCall(TrancheRegistry.initialize, (owner, address(0))))
            )
        );

        TrancheFactory factory = TrancheFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImpl),
                    abi.encodeCall(
                        TrancheFactory.initialize,
                        (owner, address(controllerImpl), address(tokenImpl), address(registry))
                    )
                )
            )
        );

        registry.setFactory(address(factory));

        vm.stopBroadcast();

        console2.log("TrancheControllerImpl", address(controllerImpl));
        console2.log("TrancheTokenImpl", address(tokenImpl));
        console2.log("TrancheRegistryImpl", address(registryImpl));
        console2.log("TrancheRegistryProxy", address(registry));
        console2.log("TrancheFactoryImpl", address(factoryImpl));
        console2.log("TrancheFactoryProxy", address(factory));
        console2.log("Owner", owner);
    }
}
