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

**Responsibilities**
- Product discovery (registry events)
- Tranche metrics (TVL, prices)
- Activity feed (deposit/redeem/accrue)

**Config**
- Update `apps/indexer/subgraph.yaml` with the TrancheRegistry address for the target chain.
- Ensure the `network` value matches Goldsky's Pharos Atlantic name before deploying.
