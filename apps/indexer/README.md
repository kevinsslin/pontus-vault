# Indexer (Goldsky)

This folder holds the Goldsky subgraph for PTI.

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
