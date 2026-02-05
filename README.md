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
- DB: Supabase
- Backend: Next.js API routes (thin BFF)
- Monorepo: pnpm + Turbo

**Repo Structure**
- `apps/web`: Next.js app (wallet connect, UI, thin API routes)
- `apps/indexer`: Goldsky subgraph (deployable indexer service)
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
pnpm --filter @pti/contracts deps
```

**BoringVault Dependency**
Install once inside `contracts/` (commit pinned):
```bash
cd contracts
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git
```

**Notes**
- `docs/PRD.md` and `plan.md` are intentionally gitignored per request.
- Frontend data source is switchable via `DATA_SOURCE` / `NEXT_PUBLIC_DATA_SOURCE` using `demo` or `live`.
- Wallet connect uses Dynamic; set `NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID` to enable the connect widget.
- Contracts test layers include unit, integration (self-deployed BoringVault stack), fork (OpenFi on Atlantic), and invariant suites.
- If you add a new workspace, update `pnpm-workspace.yaml` and root scripts.
- Dependencies are pinned to exact versions; update intentionally when needed.
