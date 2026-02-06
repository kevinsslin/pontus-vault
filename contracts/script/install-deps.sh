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

# BoringVault's teller file imports "src/..." paths. Foundry cannot safely remap
# the "src/" prefix in this workspace, so normalize to relative imports.
teller_file="lib/boring-vault/src/base/Roles/TellerWithMultiAssetSupport.sol"
if [[ -f "${teller_file}" ]]; then
  perl -0pi -e 's#from "src/base/BoringVault\.sol"#from "../BoringVault.sol"#g; s#from "src/base/Roles/AccountantWithRateProviders\.sol"#from "./AccountantWithRateProviders.sol"#g; s#from "src/interfaces/BeforeTransferHook\.sol"#from "../../interfaces/BeforeTransferHook.sol"#g; s#from "src/interfaces/IPausable\.sol"#from "../../interfaces/IPausable.sol"#g' "${teller_file}"
fi
