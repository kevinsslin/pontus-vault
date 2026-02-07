// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Tranche Factory Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice Deploys tranche controller/token clones and registers vault metadata.
interface ITrancheFactory {
    /// @notice Emitted when a required address argument is zero.
    error ZeroAddress();

    /// @notice Emitted when controller implementation is updated.
    /// @param oldImplementation Previous controller implementation.
    /// @param newImplementation New controller implementation.
    event ControllerImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    /// @notice Emitted when token implementation is updated.
    /// @param oldImplementation Previous token implementation.
    /// @param newImplementation New token implementation.
    event TokenImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    /// @notice Emitted when registry address is updated.
    /// @param oldRegistry Previous registry address.
    /// @param newRegistry New registry address.
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    /// @notice Deployment parameters for a tranche vault set.
    struct TrancheVaultConfig {
        /// @notice Underlying ERC20 asset.
        address asset;
        /// @notice BoringVault share token address.
        address vault;
        /// @notice BoringVault teller role contract.
        address teller;
        /// @notice BoringVault accountant role contract.
        address accountant;
        /// @notice BoringVault manager role contract.
        address manager;
        /// @notice Tranche controller operator role.
        address operator;
        /// @notice Tranche controller guardian role.
        address guardian;
        /// @notice Token decimals for senior/junior tranche tokens.
        uint8 tokenDecimals;
        /// @notice Static fallback senior rate (per-second WAD).
        uint256 seniorRatePerSecondWad;
        /// @notice Optional dynamic rate model contract.
        address rateModel;
        /// @notice Max senior debt ratio in basis points.
        uint256 maxSeniorRatioBps;
        /// @notice Senior tranche token name.
        string seniorName;
        /// @notice Senior tranche token symbol.
        string seniorSymbol;
        /// @notice Junior tranche token name.
        string juniorName;
        /// @notice Junior tranche token symbol.
        string juniorSymbol;
    }

    /// @notice Initializes the factory clone/proxy.
    /// @param _owner Factory owner.
    /// @param _controllerImpl Tranche controller implementation.
    /// @param _tokenImpl Tranche token implementation.
    /// @param _registry Tranche registry contract.
    function initialize(address _owner, address _controllerImpl, address _tokenImpl, address _registry) external;

    /// @notice Returns controller implementation used for cloning.
    /// @return _controllerImpl Current controller implementation.
    function controllerImpl() external view returns (address);

    /// @notice Returns token implementation used for cloning.
    /// @return _tokenImpl Current token implementation.
    function tokenImpl() external view returns (address);

    /// @notice Returns registry target used for new vault registration.
    /// @return _registry Registry address.
    function registry() external view returns (address);

    /// @notice Updates controller implementation.
    /// @param _newControllerImpl New controller implementation.
    function setControllerImpl(address _newControllerImpl) external;

    /// @notice Updates token implementation.
    /// @param _newTokenImpl New token implementation.
    function setTokenImpl(address _newTokenImpl) external;

    /// @notice Updates registry contract.
    /// @param _newRegistry New registry address.
    function setRegistry(address _newRegistry) external;

    /// @notice Computes deterministic params hash for a vault config.
    /// @param _config Tranche vault config.
    /// @return _paramsHash Deterministic hash derived from config and chain id.
    function computeParamsHash(TrancheVaultConfig calldata _config) external view returns (bytes32 _paramsHash);

    /// @notice Creates a tranche controller + tokens and registers them in registry.
    /// @param _config Tranche vault config.
    /// @return _paramsHash Params hash associated with the newly registered vault.
    function createTrancheVault(TrancheVaultConfig calldata _config) external returns (bytes32 _paramsHash);
}
