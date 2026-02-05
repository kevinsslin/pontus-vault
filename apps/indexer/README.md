# Indexer (Goldsky)

This folder holds the Goldsky subgraph for Pontus Vault.

**Prereqs**
- Goldsky CLI installed and authenticated

**Commands**
```bash
pnpm --filter @pti/indexer codegen
pnpm --filter @pti/indexer build
pnpm --filter @pti/indexer deploy
```

Set `GOLDSKY_SUBGRAPH_NAME` before deploy when needed:
```bash
export GOLDSKY_SUBGRAPH_NAME="pontus-vault/0.1.0"
```

**Responsibilities**
- Product discovery (registry events)
- Activity feed (deposit/redeem/accrue)
- Event-level tranche snapshots (`TrancheSnapshot`)
- Hourly and daily rollups (`VaultHourlySnapshot`, `VaultDailySnapshot`) with flow counters, latest state, and OHLC-style TVL/price fields for charting
- Distinct transaction counts per time bucket (`txCount`) alongside total event counts (`eventCount`)
- On-event state reconciliation against controller/token view calls (`previewV`, `seniorDebt`, `totalSupply`) to reduce drift

**Config**
- Update `apps/indexer/subgraph.yaml` with the TrancheRegistry address for the target chain.
- Ensure the `network` value matches Goldsky's Pharos Atlantic name before deploying.
- Local compile/codegen uses Graph CLI; Goldsky CLI is deploy-only.

**Example Query (Charting)**
```graphql
query VaultSnapshots($controller: String!) {
  vault(id: $controller) {
    id
    productId
    tvl
    seniorPrice
    juniorPrice
    hourlySnapshots(first: 24, orderBy: periodStart, orderDirection: desc) {
      periodStart
      txCount
      depositCount
      redeemCount
      openTvl
      highTvl
      lowTvl
      closeTvl
      openSeniorPrice
      closeSeniorPrice
      openJuniorPrice
      closeJuniorPrice
    }
    dailySnapshots(first: 30, orderBy: periodStart, orderDirection: desc) {
      periodStart
      txCount
      depositCount
      redeemCount
      openTvl
      highTvl
      lowTvl
      closeTvl
    }
  }
}
```
