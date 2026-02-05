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
- Minimal debt updates on `Accrued` events

Current limitation:
- Tranche TVL/price snapshots are schema-ready but not fully computed in mappings yet; this is pending a stable AssemblyScript-compatible enrichment pass.

**Config**
- Update `apps/indexer/subgraph.yaml` with the TrancheRegistry address for the target chain.
- Ensure the `network` value matches Goldsky's Pharos Atlantic name before deploying.
- Local compile/codegen uses Graph CLI; Goldsky CLI is deploy-only.
