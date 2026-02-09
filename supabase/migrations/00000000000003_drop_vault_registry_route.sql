-- Drop the legacy single-route column. Vault strategies are represented by ui_config.strategyKeys.
alter table if exists public.vault_registry
  drop column if exists route;

