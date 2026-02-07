# AGENTS.md

## Purpose
Keep this repo consistent and maintainable: clear structure, pinned tooling, and minimal surprises.

## Layout
- `apps/` deployable apps and services (`apps/web`, `apps/indexer`).
- `packages/` shared code (`packages/shared`).
- `contracts/` Foundry workspace (BoringVault + tranche wrapper).
- `supabase/` schema, migrations, seeds (metadata only).

## Tooling (Pinned)
- Package manager: `pnpm` pinned via root `packageManager`.
- Task runner: Turbo (`turbo.json`).
- Node: `>=20`.
- Contracts: Foundry toolchain.
- Indexer deploys: Goldsky CLI.

## Conventions
- Versions are exact and pinned (no `latest`).
- Internal package names use `@pti/*`.
- Secrets are never committed; use `.env.example`.
- Shared chain constants live in `packages/shared/src/index.ts`.
- BoringVault stays as a Foundry dependency in `contracts/lib/boring-vault`.
- If repo structure changes, update `README.md` and `pnpm-workspace.yaml`.
- Keep changes scoped and avoid large refactors unless required.

## Project-Specific Notes
- `apps/web`: Next.js App Router. Keep API routes thin.
- `apps/indexer`: Goldsky subgraph project.
- `contracts`: adhere to clean Solidity style (custom errors, CEI, safe ERC20 transfers).

## Contracts Best Practices
- One contract per file for production contracts; file name should match the main contract name.
- Expose and maintain explicit interfaces for externally integrated contracts (`ITranche*`, etc.), and keep implementations aligned with interface signatures.
- Keep function ordering consistent by visibility and role grouping:
  constructor/initializer -> external owner/admin functions -> external user functions -> public view -> internal/private helpers.
- Use leading underscore for function parameters and local temporary args (for example `_params`, `_newRate`, `_assetsIn`) consistently across contracts.
- Solidity version should track the latest version accepted by Pharos and must stay aligned with `contracts/foundry.toml` `solc_version`.
- Prefer key-based mappings over index-based arrays for onchain registries when lookup key exists (for example `paramsHash`), and avoid onchain pagination/count if indexer can serve enumeration.
- If a registry key is a hash (for example `paramsHash`), compute it onchain from canonical config fields; do not trust a caller-supplied hash.
- External protocol rate integrations must go through an adapter that implements `IRefRateProvider` and returns normalized `per-second WAD` rates; do not wire protocol-native rate APIs directly into core controllers/models.
- Emit stable key fields in events (for example `paramsHash`) so indexer/offchain systems can remain deterministic.
- Any contract API or storage-shape change must include corresponding updates to interfaces, tests, scripts, and indexer ABI/event handlers in the same change set.

## Workflow
Follow `plan.md` for execution rules and checklist handling.
- If you change anything in `supabase/migrations`, run `supabase db push` before marking work as complete.
- Do not name migration files `*_init.sql` because Supabase CLI skips them.
