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

## Workflow
Follow `plan.md` for execution rules and checklist handling.
- If you change anything in `supabase/migrations`, run `supabase db push` before marking work as complete.
- Do not name migration files `*_init.sql` because Supabase CLI skips them.
