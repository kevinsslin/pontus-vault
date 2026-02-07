// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Tranche Registry Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Stores tranche vault metadata keyed by deterministic params hash.
interface ITrancheRegistry {
    /// @notice Emitted when caller is not registered factory.
    error NotFactory();
    /// @notice Emitted when an address input is zero.
    error ZeroAddress();
    /// @notice Emitted when params hash has already been registered.
    /// @param _paramsHash Existing vault params hash.
    error TrancheVaultAlreadyRegistered(bytes32 _paramsHash);
    /// @notice Emitted when a lookup hash is not registered.
    /// @param _paramsHash Missing params hash.
    error TrancheVaultNotFound(bytes32 _paramsHash);

    /// @notice Persistent metadata for a deployed tranche vault set.
    struct TrancheVaultInfo {
        /// @notice Tranche controller address.
        address controller;
        /// @notice Senior tranche token address.
        address seniorToken;
        /// @notice Junior tranche token address.
        address juniorToken;
        /// @notice BoringVault share token address.
        address vault;
        /// @notice BoringVault teller contract.
        address teller;
        /// @notice BoringVault accountant contract.
        address accountant;
        /// @notice BoringVault manager contract.
        address manager;
        /// @notice Underlying ERC20 asset.
        address asset;
        /// @notice Deterministic params hash computed by factory.
        bytes32 paramsHash;
    }

    /// @notice Emitted when authorized factory is updated.
    /// @param oldFactory Previous factory.
    /// @param newFactory New factory.
    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);
    /// @notice Emitted when a new tranche vault record is registered.
    /// @param paramsHash Deterministic params hash.
    /// @param controller Tranche controller address.
    /// @param seniorToken Senior token address.
    /// @param juniorToken Junior token address.
    /// @param vault BoringVault share token address.
    /// @param teller Teller contract.
    /// @param accountant Accountant contract.
    /// @param manager Manager contract.
    /// @param asset Underlying asset.
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

    /// @notice Initializes registry ownership and authorized factory.
    /// @param _owner Registry owner.
    /// @param _factory Authorized factory address.
    function initialize(address _owner, address _factory) external;

    /// @notice Returns currently authorized factory.
    /// @return _factory Factory address.
    function factory() external view returns (address);

    /// @notice Updates authorized factory.
    /// @param _newFactory New factory address.
    function setFactory(address _newFactory) external;

    /// @notice Registers a tranche vault metadata record.
    /// @param _info Vault metadata bundle.
    /// @return _paramsHash Registered params hash.
    function registerTrancheVault(TrancheVaultInfo calldata _info) external returns (bytes32 _paramsHash);

    /// @notice Fetches vault metadata by params hash.
    /// @param _paramsHash Params hash key.
    /// @return _info Stored vault metadata.
    function trancheVaultByParamsHash(bytes32 _paramsHash) external view returns (TrancheVaultInfo memory _info);

    /// @notice Returns whether a params hash has been registered.
    /// @param _paramsHash Params hash key.
    /// @return _exists True when record exists.
    function trancheVaultExists(bytes32 _paramsHash) external view returns (bool _exists);
}
