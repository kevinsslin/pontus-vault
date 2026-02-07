// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Tranche Token Interface
/// @author Kevin Lin (@kevinsslin)
/// @notice ERC20-compatible tranche share token controlled by a tranche controller.
interface ITrancheToken is IERC20Metadata {
    /// @notice Emitted when a non-controller caller invokes a controller-only function.
    error NotController();
    /// @notice Emitted when an address input is zero.
    error ZeroAddress();
    /// @notice Emitted when `burnFrom` allowance is below requested burn amount.
    error InsufficientAllowance();

    /// @notice Returns the controller authorized to mint and burn tokens.
    /// @return _controller Controller address.
    function controller() external view returns (address);

    /// @notice Initializes the tranche token clone.
    /// @param _name ERC20 name.
    /// @param _symbol ERC20 symbol.
    /// @param _decimals Token decimals.
    /// @param _controller Tranche controller address.
    function initialize(string calldata _name, string calldata _symbol, uint8 _decimals, address _controller) external;

    /// @notice Mints tranche shares to a receiver.
    /// @param _to Recipient address.
    /// @param _amount Token amount to mint.
    function mint(address _to, uint256 _amount) external;

    /// @notice Burns tranche shares from an owner using controller allowance.
    /// @param _from Token owner to burn from.
    /// @param _amount Token amount to burn.
    function burnFrom(address _from, uint256 _amount) external;
}
