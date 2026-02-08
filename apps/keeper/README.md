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
