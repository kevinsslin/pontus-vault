// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ITrancheRegistry {
    error NotFactory();
    error ZeroAddress();
    error TrancheVaultAlreadyRegistered(bytes32 _paramsHash);
    error TrancheVaultNotFound(bytes32 _paramsHash);

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

    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);
    event TrancheVaultCreated(
        bytes32 indexed paramsHash,
        address indexed controller,
        address seniorToken,
        address juniorToken,
        address indexed vault,
        address teller,
        address accountant,
        address manager,
        address asset
    );

    function initialize(address _owner, address _factory) external;

    function factory() external view returns (address);

    function setFactory(address _newFactory) external;

    function registerTrancheVault(TrancheVaultInfo calldata _info) external returns (bytes32 _paramsHash);

    function trancheVaultByParamsHash(bytes32 _paramsHash) external view returns (TrancheVaultInfo memory _info);

    function trancheVaultExists(bytes32 _paramsHash) external view returns (bool _exists);
}
