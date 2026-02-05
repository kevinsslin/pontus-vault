# Contracts (Foundry)

This workspace holds the BoringVault stack integration and tranche wrapper contracts.

**Structure**
- `src/tranche/`: tranche controller/factory/registry/token/rate-model contracts
- `src/libraries/`: constants + OpenFi calldata builder
- `src/interfaces/`: OpenFi + tranche interfaces
- `script/Deploy.s.sol`: deployment entrypoint
- `script/BaseScript.sol`: shared script env helpers
- `test/unit`: isolated logic tests
- `test/integration`: full self-deployed BoringVault assembly tests
- `test/fork`: Atlantic fork tests
- `test/invariant`: property-based tests

**BoringVault Dependency**
```bash
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git
```
This repo vendors the pinned commit in `contracts/lib/boring-vault`; keep it in place for local builds.
`script/install-deps.sh` applies a minimal, deterministic teller import patch because Foundry cannot safely remap BoringVault's `src/...` imports in this workspace.

**BoringVault Deployment Helpers (Reference Only)**
- `contracts/lib/boring-vault/script/ArchitectureDeployments/DeployArcticArchitecture.sol`: baseline wiring for BoringVault + accountant + manager/roles.
- `contracts/lib/boring-vault/script/DeployTeller.s.sol`: teller deployment flow to adapt for Pharos/Atlantic assets.
- `contracts/lib/boring-vault/script/DeployDecoderAndSanitizer.s.sol`: decoder/allowlist scaffolding (use for OpenFi selectors).

No deploy scripts are run from this repo; we adapt the above patterns into `contracts/script/Deploy.s.sol`.

**Commands**
```bash
./script/install-deps.sh
forge build
forge test
forge coverage --report summary
forge fmt
```

Use pnpm helpers from the repo root if preferred:
```bash
pnpm --filter @pti/contracts deps
pnpm --filter @pti/contracts build
pnpm --filter @pti/contracts test
pnpm --filter @pti/contracts deploy
```

**Test Notes**
- `test/utils/Constants.sol`: shared numeric values for test amounts/rates/bounds.
- `test/utils/Defaults.sol`: shared default labels/symbols/config strings.
- `test/BaseTest.sol`: shared actor/rule/core-tranche setup used by all test layers.
- `test/integration/IntegrationTest.sol`: shared BoringVault deployment setup (BoringVault + `TellerWithMultiAssetSupport` + accountant + authority) for integration suites.
- Integration tests deploy the full BoringVault dependency set (vault + teller + accountant + authority) and wire tranche contracts against that deployment.
- Unit/invariant tests use local test doubles (`MockTeller`, `MockAccountant`) only for isolated controller math and invariant exploration.
- Fork tests target Pharos Atlantic OpenFi `supply/withdraw` roundtrip via `OpenFiCallBuilder`.
- Set `PHAROS_RPC_URL` to execute live fork behavior; tests skip the fork path when unset.
