create table if not exists public.operator_operations (
  operation_id uuid primary key default gen_random_uuid(),
  vault_id text not null references public.vault_registry(vault_id) on delete cascade,
  chain text not null default 'pharos-atlantic',
  job_type text not null check (
    job_type in ('DEPLOY_VAULT', 'CONFIGURE_VAULT', 'PUBLISH_VAULT', 'REBALANCE_VAULT')
  ),
  requested_by text not null,
  idempotency_key text,
  status text not null default 'CREATED' check (
    status in ('CREATED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')
  ),
  options jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requested_by, idempotency_key)
);

create table if not exists public.operator_operation_steps (
  step_id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operator_operations(operation_id) on delete cascade,
  step_index integer not null check (step_index >= 0),
  kind text not null check (kind in ('ONCHAIN', 'OFFCHAIN')),
  label text not null,
  description text,
  to_address text,
  calldata text,
  value_wei text default '0',
  status text not null default 'CREATED' check (
    status in ('CREATED', 'AWAITING_SIGNATURE', 'BROADCASTED', 'CONFIRMED', 'SUCCEEDED', 'FAILED', 'CANCELLED')
  ),
  tx_hash text,
  proof text,
  error_code text,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (operation_id, step_index)
);

create index if not exists operator_operations_vault_id_created_idx
  on public.operator_operations (vault_id, created_at desc);
create index if not exists operator_operation_steps_operation_id_step_index_idx
  on public.operator_operation_steps (operation_id, step_index);

create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists operator_operations_set_updated_at on public.operator_operations;
create trigger operator_operations_set_updated_at
before update on public.operator_operations
for each row
execute function public.set_updated_at_timestamp();

drop trigger if exists operator_operation_steps_set_updated_at on public.operator_operation_steps;
create trigger operator_operation_steps_set_updated_at
before update on public.operator_operation_steps
for each row
execute function public.set_updated_at_timestamp();

alter table public.operator_operations enable row level security;
alter table public.operator_operation_steps enable row level security;

create policy "Operator operations read" on public.operator_operations
  for select using (true);

create policy "Operator operations manage" on public.operator_operations
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "Operator steps read" on public.operator_operation_steps
  for select using (true);

create policy "Operator steps manage" on public.operator_operation_steps
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
