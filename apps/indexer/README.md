# Indexer (Goldsky)

This folder holds the Goldsky subgraph for Pontus Vault.

**Prereqs**
- Goldsky CLI installed and authenticated

**Commands**
```bash
pnpm --filter @pti/indexer abi:sync
pnpm --filter @pti/indexer codegen
pnpm --filter @pti/indexer build
pnpm --filter @pti/indexer deploy
```

Set `GOLDSKY_SUBGRAPH_NAME` before deploy when needed:
```bash
export GOLDSKY_SUBGRAPH_NAME="pontus-vault/0.1.0"
```

**Responsibilities**
- Vault discovery (registry events)
- Registry state tracking (`factory`, `vaultCount`)
- Activity feed (deposit/redeem/accrue)
- Controller config/audit events (rate model, teller, caps, pause state)
- Access-control audit trail (`RoleGranted` / `RoleRevoked`)
- Event-level tranche snapshots (`TrancheSnapshot`)
- Hourly and daily rollups (`VaultHourlySnapshot`, `VaultDailySnapshot`) with flow counters, latest state, and OHLC-style TVL/price fields for charting
- Distinct transaction counts per time bucket (`txCount`) alongside total event counts (`eventCount`)
- On-event state reconciliation against controller/token view calls (`previewV`, `seniorDebt`, `totalSupply`) to reduce drift

**Config**
- Update `apps/indexer/subgraph.yaml` with the TrancheRegistry address for the target chain.
- Ensure the `network` value matches Goldsky's Pharos Atlantic name before deploying.
- Local compile/codegen uses Graph CLI; Goldsky CLI is deploy-only.
- Keep ABI synced to latest contracts before deploy (best practice):
  1. `pnpm --filter @pti/contracts build`
  2. `pnpm --filter @pti/indexer abi:sync`
- Update registry/start block in manifest via helper script:
  - `bash contracts/script/update-indexer-subgraph.sh --registry <REGISTRY> --start-block <BLOCK>`

**Example Query (Charting)**
```graphql
query VaultSnapshots($controller: String!) {
  vault(id: $controller) {
    id
    vaultId
    paramsHash
    paused
    tvl
    seniorApyBps
    juniorApyBps
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
      closeSeniorPrice
      closeJuniorPrice
      openTvl
      highTvl
      lowTvl
      closeTvl
    }
  }
}
```

**Additional Query (Registry + Roles)**
```graphql
query RegistryAndEvents($registry: String!, $controller: String!) {
  registryConfig(id: $registry) {
    factory
    vaultCount
    updatedAt
  }
  vault(id: $controller) {
    events(first: 20, orderBy: timestamp, orderDirection: desc, where: { type_in: ["ROLE_GRANTED", "ROLE_REVOKED"] }) {
      type
      role
      actor
      sender
      timestamp
      txHash
    }
  }
}
```
