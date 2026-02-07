#!/usr/bin/env bash
set -euo pipefail

# Foundry dependencies are vendored locally but intentionally gitignored.
# Keep installs pinned so CI and local environments resolve the same code.
if [[ ! -d "lib/forge-std" ]]; then
  forge install foundry-rs/forge-std@1801b0541f4fda118a10798fd3486bb7051c5dd6 --no-git
fi

if [[ ! -d "lib/oz-contracts-v5" ]]; then
  forge install oz-contracts-v5=OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git -j 8
fi

if [[ ! -d "lib/oz-contracts-upgradeable-v5" ]]; then
  forge install oz-contracts-upgradeable-v5=OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.2 --no-git -j 8
fi

if [[ ! -d "lib/boring-vault" ]]; then
  forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git -j 8
fi

# BoringVault pins many files to "pragma solidity 0.8.21;". Relax those to
# "^0.8.21" so this workspace can compile against newer compiler versions.
if [[ -d "lib/boring-vault/src" ]]; then
  find lib/boring-vault/src -type f -name '*.sol' -print0 | \
    xargs -0 perl -pi -e 's/pragma solidity 0\.8\.21;/pragma solidity ^0.8.21;/g'
fi

# Normalize selected BoringVault "src/..." imports to relative imports so this
# workspace can compile manager/decoder paths without global remap collisions.
teller_file="lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol"
manager_file="lib/boring-vault/src/base/Roles/ManagerWithMerkleVerification.sol"
base_decoder_file="lib/boring-vault/src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"
balancer_interface_file="lib/boring-vault/src/interfaces/BalancerVault.sol"

if [[ -f "${teller_file}" ]]; then
  perl -0pi -e 's#from "src/base/BoringVault\.sol"#from "../BoringVault.sol"#g; s#from "src/base/Roles/AccountantWithRateProviders\.sol"#from "./AccountantWithRateProviders.sol"#g; s#from "src/interfaces/BeforeTransferHook\.sol"#from "../../interfaces/BeforeTransferHook.sol"#g; s#from "src/interfaces/IPausable\.sol"#from "../../interfaces/IPausable.sol"#g' "${teller_file}"
fi

if [[ -f "${manager_file}" ]]; then
  perl -0pi -e 's#from "src/base/BoringVault\.sol"#from "../BoringVault.sol"#g; s#from "src/interfaces/BalancerVault\.sol"#from "../../interfaces/BalancerVault.sol"#g; s#from "src/interfaces/IPausable\.sol"#from "../../interfaces/IPausable.sol"#g; s#from "src/base/Drones/DroneLib\.sol"#from "../Drones/DroneLib.sol"#g' "${manager_file}"
fi

if [[ -f "${base_decoder_file}" ]]; then
  perl -0pi -e 's#from "src/interfaces/DecoderCustomTypes\.sol"#from "../../interfaces/DecoderCustomTypes.sol"#g' "${base_decoder_file}"
fi

if [[ -f "${balancer_interface_file}" ]]; then
  perl -0pi -e 's#from "src/interfaces/DecoderCustomTypes\.sol"#from "./DecoderCustomTypes.sol"#g' "${balancer_interface_file}"
fi
