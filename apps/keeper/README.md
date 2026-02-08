# Keeper Worker

This worker runs a periodic exchange-rate update tick for BoringVault accountant.

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
