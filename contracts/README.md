# Contracts (Foundry)

This workspace contains the Pontus Vault onchain stack: tranche infra plus a BoringVault-based vault assembly.

## Structure

- `src/tranche/`: tranche controller/factory/registry/token contracts
- `src/rate-models/`: tranche rate models
- `src/decoders/`: manager decoder/sanitizers (allowlist safety)
- `src/libraries/`: protocol calldata builders + constants + Merkle helpers
- `src/interfaces/**`: external protocol + Pontus interfaces
- `script/DeployInfra.s.sol`: one-time infra deploy (UUPS `TrancheRegistry` + `TrancheFactory`)
- `script/DeployTrancheVault.s.sol`: per-vault deploy (BoringVault set + tranche vault creation)
- `script/UpdateExchangeRate.s.sol`: accountant rate update tick
- `test/unit`, `test/integration`, `test/fork`, `test/invariant`

## Upgradeability

- `TrancheRegistry` and `TrancheFactory` are UUPS proxies.
- Storage uses ERC-7201 namespaced storage (`@custom:storage-location`) instead of storage gaps.

## Dependencies (BoringVault)

Pinned commit:
- `Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528`

Install (recommended):
```bash
pnpm --filter @pti/contracts deps
```

Manual install:
```bash
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git
```

`script/install-deps.sh` applies a minimal deterministic patch for teller imports because Foundry cannot safely remap BoringVault `src/...` imports in this workspace.

## Commands

```bash
pnpm --filter @pti/contracts build
pnpm --filter @pti/contracts test
pnpm --filter @pti/contracts test:fork
pnpm --filter @pti/contracts lint
```

## Environment

See `contracts/.env.example`. The most common vars are:
- `PHAROS_ATLANTIC_RPC_URL` (fork tests + deploy scripts)
- `PRIVATE_KEY` (deploy scripts)
- `TRANCHE_FACTORY` / `TRANCHE_REGISTRY` (per-vault deploy and wiring)

## Deployments

Current Pharos Atlantic deployments and verification status are listed in the root `README.md`.
