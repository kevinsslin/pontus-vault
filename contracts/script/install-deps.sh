#!/usr/bin/env bash
set -euo pipefail

# Foundry dependencies are vendored locally but intentionally gitignored.
# Keep installs pinned so CI and local environments resolve the same code.
forge install foundry-rs/forge-std@1801b0541f4fda118a10798fd3486bb7051c5dd6 --no-git
forge install OpenZeppelin/openzeppelin-contracts@v5.5.0 --no-git
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.5.0 --no-git
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git -j 8

# Normalize BoringVault teller imports for Foundry solar coverage/lint compatibility.
teller_file="lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol"
if [[ -f "${teller_file}" ]]; then
  sed -i.bak 's|from "src/base/BoringVault.sol"|from "../BoringVault.sol"|g' "${teller_file}"
  sed -i.bak 's|from "src/base/Roles/AccountantWithRateProviders.sol"|from "./AccountantWithRateProviders.sol"|g' "${teller_file}"
  sed -i.bak 's|from "src/interfaces/BeforeTransferHook.sol"|from "../../interfaces/BeforeTransferHook.sol"|g' "${teller_file}"
  sed -i.bak 's|from "src/interfaces/IPausable.sol"|from "../../interfaces/IPausable.sol"|g' "${teller_file}"
  rm -f "${teller_file}.bak"
fi
