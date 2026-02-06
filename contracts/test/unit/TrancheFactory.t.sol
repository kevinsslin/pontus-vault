// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {TrancheFactoryV2} from "../mocks/TrancheFactoryV2.sol";
import {TestConstants} from "../utils/Constants.sol";
import {TestDefaults} from "../utils/Defaults.sol";

contract TrancheFactoryTest is Test {
    address internal owner;
    address internal outsider;
    address internal registry;

    TrancheFactory internal factory;
    TrancheController internal controllerImpl;
    TrancheToken internal tokenImpl;

    function setUp() public {
        owner = makeAddr("owner");
        outsider = makeAddr("outsider");
        registry = makeAddr("registry");
        controllerImpl = new TrancheController();
        tokenImpl = new TrancheToken();

        TrancheFactory factoryImpl = new TrancheFactory();
        factory = TrancheFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImpl),
                    abi.encodeCall(
                        TrancheFactory.initialize, (owner, address(controllerImpl), address(tokenImpl), registry)
                    )
                )
            )
        );
    }

    function test_initialize_revertsWhenControllerImplIsZero() public {
        TrancheFactory factoryImpl = new TrancheFactory();
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(TrancheFactory.initialize, (owner, address(0), address(tokenImpl), registry))
        );
    }

    function test_initialize_revertsWhenTokenImplIsZero() public {
        TrancheFactory factoryImpl = new TrancheFactory();
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(TrancheFactory.initialize, (owner, address(controllerImpl), address(0), registry))
        );
    }

    function test_setRegistry_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        factory.setRegistry(address(2));
    }

    function test_setRegistry_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        factory.setRegistry(address(0));
    }

    function test_createTrancheVault_revertsWhenRegistryIsUnset() public {
        TrancheFactory factoryImpl = new TrancheFactory();
        TrancheFactory localFactory = TrancheFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImpl),
                    abi.encodeCall(
                        TrancheFactory.initialize, (owner, address(controllerImpl), address(tokenImpl), address(0))
                    )
                )
            )
        );

        TrancheFactory.TrancheVaultConfig memory config = _defaultConfig();

        vm.prank(owner);
        vm.expectRevert(TrancheFactory.ZeroAddress.selector);
        localFactory.createTrancheVault(config);
    }

    function test_setControllerImpl_updatesImplementation() public {
        TrancheController nextImpl = new TrancheController();

        vm.prank(owner);
        factory.setControllerImpl(address(nextImpl));

        assertEq(factory.controllerImpl(), address(nextImpl));
    }

    function test_setTokenImpl_updatesImplementation() public {
        TrancheToken nextImpl = new TrancheToken();

        vm.prank(owner);
        factory.setTokenImpl(address(nextImpl));

        assertEq(factory.tokenImpl(), address(nextImpl));
    }

    function test_upgradeToAndCall_revertsForNonOwner() public {
        TrancheFactoryV2 newImpl = new TrancheFactoryV2();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        factory.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgradeToAndCall_preservesWiring() public {
        TrancheFactoryV2 newImpl = new TrancheFactoryV2();

        vm.prank(owner);
        factory.upgradeToAndCall(address(newImpl), "");

        assertEq(factory.controllerImpl(), address(controllerImpl));
        assertEq(factory.tokenImpl(), address(tokenImpl));
        assertEq(factory.registry(), registry);
        assertEq(TrancheFactoryV2(address(factory)).version(), 2);
    }

    function _defaultConfig() internal pure returns (TrancheFactory.TrancheVaultConfig memory) {
        return TrancheFactory.TrancheVaultConfig({
            paramsHash: bytes32(0),
            asset: address(1),
            vault: address(2),
            teller: address(3),
            accountant: address(4),
            manager: address(5),
            operator: address(6),
            guardian: address(7),
            tokenDecimals: TestConstants.USDC_DECIMALS,
            seniorRatePerSecondWad: 0,
            rateModel: address(0),
            maxSeniorRatioBps: TestConstants.DEFAULT_MAX_SENIOR_RATIO_BPS,
            seniorName: TestDefaults.SENIOR_TOKEN_NAME,
            seniorSymbol: TestDefaults.SENIOR_TOKEN_SYMBOL,
            juniorName: TestDefaults.JUNIOR_TOKEN_NAME,
            juniorSymbol: TestDefaults.JUNIOR_TOKEN_SYMBOL
        });
    }
}
