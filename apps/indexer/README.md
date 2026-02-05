# Indexer (Goldsky)

This folder holds the Goldsky subgraph for PTVI.

**Prereqs**
- Goldsky CLI installed and authenticated

**Commands**
```bash
pnpm --filter @ptvi/indexer codegen
pnpm --filter @ptvi/indexer build
pnpm --filter @ptvi/indexer deploy
```

**Responsibilities**
- Product discovery (registry events)
- Tranche metrics (TVL, prices)
- Activity feed (deposit/redeem/accrue)
