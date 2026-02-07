// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ITrancheFactory {
    error ZeroAddress();

    event ControllerImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event TokenImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    struct TrancheVaultConfig {
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

    function initialize(address _owner, address _controllerImpl, address _tokenImpl, address _registry) external;

    function controllerImpl() external view returns (address);

    function tokenImpl() external view returns (address);

    function registry() external view returns (address);

    function setControllerImpl(address _newControllerImpl) external;

    function setTokenImpl(address _newTokenImpl) external;

    function setRegistry(address _newRegistry) external;

    function computeParamsHash(TrancheVaultConfig calldata _config) external view returns (bytes32 _paramsHash);

    function createTrancheVault(TrancheVaultConfig calldata _config) external returns (bytes32 _paramsHash);
}
