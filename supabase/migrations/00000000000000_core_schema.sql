-- NOTE: Supabase CLI skips migration files named "*_init.sql".
-- Keep this as a normal timestamped migration file so `supabase db push` applies it.
create extension if not exists "pgcrypto";

create table if not exists public.vault_registry (
  vault_id text primary key,
  chain text not null,
  name text not null,
  route text not null,
  asset_symbol text not null,
  asset_address text not null,
  controller_address text not null,
  senior_token_address text not null,
  junior_token_address text not null,
  vault_address text not null,
  teller_address text not null,
  manager_address text not null,
  ui_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.watchlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  vault_id text not null references public.vault_registry(vault_id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, vault_id)
);

alter table public.vault_registry enable row level security;
alter table public.watchlists enable row level security;

create policy "Vault registry read" on public.vault_registry
  for select using (true);

create policy "Vault registry manage" on public.vault_registry
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

create policy "Watchlists read own" on public.watchlists
  for select using (auth.uid() = user_id);

create policy "Watchlists insert own" on public.watchlists
  for insert with check (auth.uid() = user_id);

create policy "Watchlists update own" on public.watchlists
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Watchlists delete own" on public.watchlists
  for delete using (auth.uid() = user_id);
