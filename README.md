# Pontus Vault

Pontus Vault is tranche vault infrastructure on Pharos. It packages yield strategies into tiered vault structures that are easy to understand, integrate, and distribute.

**Overview**
- Tiered risk/return vault sleeves backed by the same strategy pool
- A consistent vault interface for pricing, performance, and redemptions
- A strategy library spanning DeFi and real-world yield (treasuries, money markets, private credit, market-neutral, etc.)
- Yield that accrues into value automatically (no “claim yield” UX)
- White-label distribution for wallets, exchanges, and fintechs

**Stack**
- Frontend: Next.js (App Router)
- Contracts: Foundry + BoringVault
- Indexer: Goldsky
- Keeper: Node.js worker (scheduled accountant exchange-rate updates)
- DB: Supabase
- Backend: Next.js API routes (thin BFF)
- Monorepo: pnpm + Turbo

**Repo Structure**
- `apps/web`: Next.js app (wallet connect, UI, thin API routes)
- `apps/indexer`: Goldsky subgraph (deployable indexer service)
- `apps/keeper`: scheduled worker for `updateExchangeRate` execution
- `contracts`: Foundry workspace (BoringVault stack + tranche wrapper)
- `packages/shared`: shared types/constants
- `supabase`: schema, migrations, seeds

Why this layout: `apps/` contains deployable apps/services, `packages/` contains shared code, and `contracts/` stays isolated for Foundry tooling.

**Prerequisites**
- Node.js `>=20`
- `pnpm`
- Foundry toolchain (`forge`, `cast`)
- Goldsky CLI (for indexer deploys)
- Supabase CLI (optional, for local DB work)

**Install**
```bash
pnpm install
```

**Common Commands**
```bash
pnpm dev
pnpm build
pnpm test
pnpm lint
pnpm keeper:start
pnpm keeper:once
pnpm --filter @pti/contracts deps
pnpm --filter @pti/contracts test:fork
pnpm --filter @pti/contracts deploy:infra
pnpm --filter @pti/contracts deploy:vault
pnpm --filter @pti/contracts keeper:update-rate
```

**End-to-End Runbook (Create Vault -> Index -> Operate)**
1. Deploy core infra (UUPS registry/factory):
   `pnpm --filter @pti/contracts deploy:infra`
2. Deploy one vault stack (BoringVault + teller + accountant + manager + tranche set):
   `pnpm --filter @pti/contracts deploy:vault`
3. Record deploy outputs:
   persist `controller`, `seniorToken`, `juniorToken`, `vault`, `teller`, `manager`, `paramsHash` in `supabase.vault_registry`.
4. Point indexer to your registry:
   run `contracts/script/update-indexer-subgraph.sh --registry <TRANCHE_REGISTRY> --start-block <DEPLOY_START_BLOCK>`
   (or edit `apps/indexer/subgraph.yaml` manually), then verify `dataSources[0].source.address` and `startBlock`.
5. Build and deploy subgraph:
   `pnpm --filter @pti/indexer build`
   `pnpm --filter @pti/indexer deploy`
6. Enable live data path:
   set `DATA_SOURCE=live`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `INDEXER_URL`.
7. Start keeper for accountant updates:
   `pnpm keeper:start` (or one-off: `pnpm keeper:once`).
8. Run operator workflows from `/operator`:
   configure vault profile/caps/routes, then execute rebalance with `raise-cash` intent before large redemptions when needed.

**Manual vs Server-Side Execution**
- Manual execution:
  best for bootstrap deploys, one-off maintenance, and break-glass operations.
- Server-side execution:
  best for recurring jobs (keeper rate updates, scheduled rebalance, operation persistence).
- Recommended:
  hybrid model. Keep deploy + emergency actions manual; move repetitive tasks to server workers/API with logs and idempotency keys.

**BoringVault Dependency**
Install once inside `contracts/` (commit pinned):
```bash
cd contracts
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git
```

**Notes**
- `docs/PRD.md` and `plan.md` are intentionally gitignored per request.
- Frontend data source is switchable via `DATA_SOURCE` / `NEXT_PUBLIC_DATA_SOURCE` using `demo` or `live`.
- Live data mode expects server envs: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `INDEXER_URL`.
- Wallet connect uses Dynamic; set `NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID` to enable the connect widget.
- Operator flow uses `Next.js API + wallet-signed step runner`:
  - `POST/GET /api/operator/operations`
  - `GET /api/operator/operations/:operationId`
  - `PATCH /api/operator/operations/:operationId/steps/:stepIndex`
  - `PATCH /api/operator/vaults/:vaultId` (vault profile metadata: name/summary/risk/status/order/tags)
- Operator persistence tables are `operator_operations` and `operator_operation_steps` in Supabase.
- `NEXT_PUBLIC_OPERATOR_TX_MODE=send_transaction` enables direct wallet tx broadcast on onchain steps; default behavior is `sign_only`.
- `OPERATOR_ADMIN_ADDRESSES` can lock operator write actions to a comma-separated wallet allowlist; in `demo` mode an empty allowlist is allowed.
- Contracts test layers include unit, integration (self-deployed BoringVault stack), fork (OpenFi on Atlantic), and invariant suites.
- Tranche deposits can be guarded by accountant rate staleness (`maxRateAge`), so production should run the keeper worker continuously.
- Hybrid withdraw with tranche `QueueAdapter` is tracked as a future roadmap item in `contracts/README.md` (deferred in the current release).
- `CapSafetyRateModel` consumes `IRefRateProvider` only. To use a real external protocol rate, deploy an adapter that implements `IRefRateProvider` and normalizes output to `per-second WAD`.
- Reference implementation: `OpenFiRayRateAdapter` + `IOpenFiRateSource` for `ray/year -> per-second WAD` normalization.
- If you add a new workspace, update `pnpm-workspace.yaml` and root scripts.
- Dependencies are pinned to exact versions; update intentionally when needed.
- Pharos Atlantic chain id is standardized as `688689` across wallet network config, deploy scripts, and keeper jobs.
