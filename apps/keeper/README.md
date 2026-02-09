# Keeper

This package contains server-side workers that run Foundry scripts and write results back to the Pontus operator database (Supabase).

## Modes

- **Rate updater** (`pnpm --filter @pti/keeper start`): periodically pushes `AccountantWithRateProviders.updateExchangeRate(...)`.
- **Deploy executor** (`pnpm --filter @pti/keeper start:deploy-executor`): HTTP service used by the operator UI (optional).
- **Operator worker** (`pnpm --filter @pti/keeper start:operator-worker`): async worker that polls Supabase for queued operator steps, runs Foundry, and persists results.

## Purpose

- Run `contracts/script/UpdateExchangeRate.s.sol` on a schedule.
- Push latest exchange rate (`updateExchangeRate`) from current vault assets and total share supply.
- Keep `TrancheController` deposit staleness guard healthy (`maxRateAge`).

## Required Environment

- `PHAROS_ATLANTIC_RPC_URL`
- `PRIVATE_KEY`
- `VAULT`
- `ACCOUNTANT`
- `ASSET`

## Optional Environment

- `MIN_UPDATE_BPS` (default `1`)
- `ALLOW_PAUSE_UPDATE` (default `false`)
- `KEEPER_INTERVAL_MS` (default `300000`)
- `KEEPER_RUN_ONCE` (default `false`)
- `KEEPER_CONTRACTS_DIR` (default `../../contracts` from this app)

## Run

```bash
pnpm --filter @pti/keeper start
```

Single tick:

```bash
pnpm --filter @pti/keeper start:once
```

## Deploy Executor Worker

This worker exposes an HTTP endpoint so web/operator UI can trigger contract deploy automation.

### Endpoints

- `GET /health`
- `POST /deploy`
- `POST /update-rate`

### Required Environment

- `PHAROS_ATLANTIC_RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `TRANCHE_FACTORY`

### Optional Environment

- `CONTRACTS_WORKSPACE_DIR` (or `KEEPER_CONTRACTS_DIR`)
- `DEPLOYER_OPERATOR`
- `DEPLOYER_GUARDIAN`
- `DEPLOYER_STRATEGIST`
- `DEPLOYER_MANAGER_ADMIN`
- `ACCOUNTANT_UPDATER_PRIVATE_KEY` (fallback: `PRIVATE_KEY`, then `DEPLOYER_PRIVATE_KEY`)
- `DEPLOY_EXECUTOR_TOKEN`
- `DEPLOY_EXECUTOR_HOST` (default `0.0.0.0`)
- `DEPLOY_EXECUTOR_PORT` (default `8787`)

### Run

```bash
pnpm --filter @pti/keeper start:deploy-executor
```

### Deploy on Railway

Use **this folder’s Dockerfile** (`apps/keeper/Dockerfile`). The build context must be the **repo root** (so `contracts/`, `packages/`, and root `package.json` are available). The repo root’s **`.dockerignore`** applies to that context.

1. New Project → Deploy from GitHub → select this repo.
2. **Root Directory**: leave empty (context = repo root).
3. **Settings → Build**: set **Dockerfile path** to `apps/keeper/Dockerfile`.
4. **Start Command**: leave empty (the Dockerfile sets `CMD`).
5. **Variables**: set `PHAROS_ATLANTIC_RPC_URL`, `DEPLOYER_PRIVATE_KEY`, `TRANCHE_FACTORY`. Optionally `CONTRACTS_WORKSPACE_DIR=/app/contracts`, `DEPLOY_EXECUTOR_TOKEN`, and role addresses. See **`.env.example`** in this folder.

The app listens on `PORT` or `DEPLOY_EXECUTOR_PORT` (default 8787); Railway injects `PORT` automatically.

## Operator Worker

This worker is the production async path for **vault deployment execution**.

### What It Does

1. Poll `operator_operation_steps` for `label = "Execute deployment transaction"` and `status = "BROADCASTED"`.
2. Atomically claim the step by transitioning it to `RUNNING`.
3. Run `forge script script/DeployTrancheVault.s.sol --broadcast --verify ...`.
4. Write deployed addresses and metadata to `vault_registry` (including `ui_config.paramsHash`, `ui_config.deployTxHash`, and an `ui_config.indexerStartBlock` hint when available).
5. Mark the deployment step `CONFIRMED` and advance the next step (register outputs) to `SUCCEEDED`.

### Required Environment

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPERATOR_ADMIN_ADDRESSES` (comma-separated allowlist; required to prevent unbounded execution)
- `PHAROS_ATLANTIC_RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `TRANCHE_FACTORY`

### Optional Environment

- `CONTRACTS_WORKSPACE_DIR` (or `KEEPER_CONTRACTS_DIR`)
- `DEPLOYER_OPERATOR`
- `DEPLOYER_GUARDIAN`
- `DEPLOYER_STRATEGIST`
- `DEPLOYER_MANAGER_ADMIN`
- `KEEPER_WORKER_INTERVAL_MS` (default `3000`)

### Run

```bash
pnpm --filter @pti/keeper start:operator-worker
```
