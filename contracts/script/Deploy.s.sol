// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {DeployInfra} from "./DeployInfra.s.sol";

// Backward-compatible entrypoint: defaults to one-time infra deployment.
contract Deploy is DeployInfra {}
