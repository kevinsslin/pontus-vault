# Pontus Demo TODO

This is the complete demo runbook for your current architecture.
Assumption: Supabase and Vercel projects already exist.

## What Is Automated Now

- Vault deployment can be triggered from `/operator`.
- Backend deploy API (`/api/operator/deploy`) executes deployment using server credentials.
- Successful deploy automatically upserts `public.vault_registry`.
- Accountant rate refresh can be triggered from `/operator` (Accountant module) via `/api/operator/accountant/update-rate`.
- Operator can read infra bindings (`TRANCHE_FACTORY` / `TRANCHE_REGISTRY`) via `/api/operator/infra`.

## What Is Still Manual

- One-time infra bootstrap (`deploy:infra`) to get `TRANCHE_FACTORY`.
- Indexer deploy (build + deploy command).
- Keeper deployment and process management.

## Current TODO (Actionable)

- Bootstrap infra once and record `TRANCHE_FACTORY` + `TRANCHE_REGISTRY`.
- Enable deploy automation backend (local Forge mode or remote deploy worker mode).
- Trigger vault deploy from `/operator` and confirm auto-sync to Supabase.
- Deploy indexer and set live indexer URL.
- Run keeper continuously for accountant updates.

## 1. Preflight

1. Install and verify:
```bash
pnpm install
cd contracts && ./script/install-deps.sh
cd contracts && forge test
```
2. Confirm target chain:
- Pharos Atlantic, `chainId = 688689`.

## 2. One-Time Infra Bootstrap

Run once per environment:
```bash
cd contracts
pnpm deploy:infra
```

Save from output:
- `TrancheFactoryProxy` -> `TRANCHE_FACTORY`
- `TrancheRegistryProxy` -> indexer registry address

Notes:
- Deployment scripts already use `--broadcast --verify`.
- Verification target is Blockscout.

## 3. Choose Deploy Automation Mode

Use exactly one mode.

### Mode A: Local Forge Executor (single host)

Set web server env:
- `PHAROS_ATLANTIC_RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `TRANCHE_FACTORY`
- `CONTRACTS_WORKSPACE_DIR` (absolute path to `contracts/`)
- Optional:
  - `DEPLOYER_OPERATOR`
  - `DEPLOYER_GUARDIAN`
  - `DEPLOYER_STRATEGIST`
  - `DEPLOYER_MANAGER_ADMIN`

### Mode B: Remote Deploy Worker (recommended with Vercel)

Start worker:
```bash
pnpm --filter @pti/keeper start:deploy-executor
```

Worker required env:
- `PHAROS_ATLANTIC_RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `TRANCHE_FACTORY`
- Optional:
  - `ACCOUNTANT_UPDATER_PRIVATE_KEY` (fallback: `PRIVATE_KEY`, then `DEPLOYER_PRIVATE_KEY`)
  - `CONTRACTS_WORKSPACE_DIR` (or `KEEPER_CONTRACTS_DIR`)
  - `DEPLOY_EXECUTOR_TOKEN`
  - `DEPLOYER_OPERATOR`
  - `DEPLOYER_GUARDIAN`
  - `DEPLOYER_STRATEGIST`
  - `DEPLOYER_MANAGER_ADMIN`

Set web env:
- `DEPLOY_EXECUTOR_URL`
- Optional `DEPLOY_EXECUTOR_TOKEN`

## 4. Configure Web Live Mode

Set Vercel env:
- `NEXT_PUBLIC_DATA_SOURCE=live`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `INDEXER_URL` (or `NEXT_PUBLIC_INDEXER_URL`, set after indexer deploy)
- `NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID`
- Optional:
  - `OPERATOR_ADMIN_ADDRESSES`
  - `NEXT_PUBLIC_OPERATOR_TX_MODE=send_transaction`

Redeploy web app.

## 5. Deploy Vault From UI (No Manual Supabase Insert)

1. Open `/operator`.
2. Select target vault profile.
3. Go to `Vault Factory`.
4. Set optional `Owner address` (or keep connected wallet as owner).
5. Click `Prepare operation`.
6. In operation detail, execute step `Execute deployment transaction` with `Deploy & sync`.
7. Switch to `Accountant` module and run `Update exchange rate` for the deployed vault.

Expected result:
- Deploy succeeds onchain.
- `vault_registry` row is created/updated automatically.
- Returned metadata includes controller/senior/junior/vault/teller/manager/accountant and params hash.

## 6. Deploy Indexer

1. Update registry address/start block:
```bash
bash contracts/script/update-indexer-subgraph.sh \
  --registry <TRANCHE_REGISTRY_PROXY_ADDRESS> \
  --start-block <DEPLOY_START_BLOCK>
```
Tip:
- `/operator -> Vault Factory` now shows current `TrancheRegistry` and a ready-to-copy indexer command template.
- `indexerStartBlock` is auto-populated when deploy API can resolve the deployment receipt.
2. Build and deploy:
```bash
pnpm --filter @pti/indexer abi:sync
pnpm --filter @pti/indexer build
pnpm --filter @pti/indexer deploy
```
3. Save GraphQL endpoint as `INDEXER_URL` and redeploy web.

## 7. Start Keeper

Required env:
- `PHAROS_ATLANTIC_RPC_URL`
- `PRIVATE_KEY`
- `VAULT`
- `ACCOUNTANT`
- `ASSET`

Run:
```bash
pnpm --filter @pti/keeper start
```

One-shot:
```bash
pnpm --filter @pti/keeper start:once
```

## 8. Demo Script

1. `/operator`:
- Trigger one vault deploy using `Deploy & sync`.
- Show deployed addresses and operation history.
2. `/discover`:
- Show vault appears from live data.
3. `/vaults/[id]`:
- Show metrics sourced from indexer.
4. Keeper:
- Run one tick (or show scheduled logs) for rate update.
5. `/operator`:
- Update risk caps / listing status to `LIVE`.

## 9. Fallback Manual Path

If deploy API is unavailable:
1. Run `pnpm deploy:vault` from `contracts`.
2. Upsert `vault_registry` manually in Supabase.
3. Continue with indexer + keeper.

## 10. Final Checklist

- [ ] `deploy:infra` done and `TRANCHE_FACTORY` configured
- [ ] deploy automation mode selected and env configured
- [ ] UI deploy completed (`Deploy & sync` successful)
- [ ] `vault_registry` auto-upsert confirmed
- [ ] indexer deployed and `INDEXER_URL` set
- [ ] web redeployed in `live` mode
- [ ] keeper running
- [ ] end-to-end demo walkthrough validated
