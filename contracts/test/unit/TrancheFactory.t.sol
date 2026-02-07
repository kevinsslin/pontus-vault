// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {TrancheController} from "../../src/tranche/TrancheController.sol";
import {TrancheFactory} from "../../src/tranche/TrancheFactory.sol";
import {TrancheToken} from "../../src/tranche/TrancheToken.sol";
import {ITrancheFactory} from "../../src/interfaces/ITrancheFactory.sol";
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
        vm.expectRevert(ITrancheFactory.ZeroAddress.selector);
        new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(TrancheFactory.initialize, (owner, TestConstants.ZERO_ADDRESS, address(tokenImpl), registry))
        );
    }

    function test_initialize_revertsWhenTokenImplIsZero() public {
        TrancheFactory factoryImpl = new TrancheFactory();
        vm.expectRevert(ITrancheFactory.ZeroAddress.selector);
        new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(
                TrancheFactory.initialize, (owner, address(controllerImpl), TestConstants.ZERO_ADDRESS, registry)
            )
        );
    }

    function test_setRegistry_revertsForNonOwner() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, outsider));
        factory.setRegistry(TestConstants.CONFIG_VAULT);
    }

    function test_setRegistry_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ITrancheFactory.ZeroAddress.selector);
        factory.setRegistry(TestConstants.ZERO_ADDRESS);
    }

    function test_createTrancheVault_revertsWhenRegistryIsUnset() public {
        TrancheFactory factoryImpl = new TrancheFactory();
        TrancheFactory localFactory = TrancheFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImpl),
                    abi.encodeCall(
                        TrancheFactory.initialize,
                        (owner, address(controllerImpl), address(tokenImpl), TestConstants.ZERO_ADDRESS)
                    )
                )
            )
        );

        ITrancheFactory.TrancheVaultConfig memory config = _defaultConfig();

        vm.prank(owner);
        vm.expectRevert(ITrancheFactory.ZeroAddress.selector);
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

    function _defaultConfig() internal pure returns (ITrancheFactory.TrancheVaultConfig memory) {
        return ITrancheFactory.TrancheVaultConfig({
            paramsHash: bytes32(0),
            asset: TestConstants.CONFIG_ASSET,
            vault: TestConstants.CONFIG_VAULT,
            teller: TestConstants.CONFIG_TELLER,
            accountant: TestConstants.CONFIG_ACCOUNTANT,
            manager: TestConstants.CONFIG_MANAGER,
            operator: TestConstants.CONFIG_OPERATOR,
            guardian: TestConstants.CONFIG_GUARDIAN,
            tokenDecimals: TestConstants.USDC_DECIMALS,
            seniorRatePerSecondWad: TestConstants.DEFAULT_SENIOR_RATE_PER_SECOND_WAD,
            rateModel: TestConstants.ZERO_ADDRESS,
            maxSeniorRatioBps: TestConstants.DEFAULT_MAX_SENIOR_RATIO_BPS,
            seniorName: TestDefaults.SENIOR_TOKEN_NAME,
            seniorSymbol: TestDefaults.SENIOR_TOKEN_SYMBOL,
            juniorName: TestDefaults.JUNIOR_TOKEN_NAME,
            juniorSymbol: TestDefaults.JUNIOR_TOKEN_SYMBOL
        });
    }
}
