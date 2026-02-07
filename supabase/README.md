# Supabase

This folder contains migrations, RLS policies, and seed data for:

- Metadata tables (`vault_registry`, `watchlists`)
- Operator audit trail tables (`operator_operations`, `operator_operation_steps`)

Operator table goals:
- Persist operation intent (`job_type`, `idempotency_key`, `requested_by`)
- Persist step-level execution (`status`, `tx_hash`, `proof`, `error_*`)
- Enable replay/review after demo runs

Migration naming note:
- Avoid `*_init.sql` naming because `supabase db push` skips it.
- Use normal timestamped names like `00000000000000_core_schema.sql`.
