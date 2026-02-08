// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BaseForkTest} from "../fork/BaseForkTest.sol";

/// @title Base E2E Test
/// @author Kevin Lin (@kevinsslin)
/// @notice Shared base for end-to-end scenarios that run against the pinned Pharos fork.
abstract contract BaseE2ETest is BaseForkTest {}
