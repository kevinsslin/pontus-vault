-- Extend operator step status to include RUNNING (worker-claimed execution).
alter table public.operator_operation_steps
  drop constraint if exists operator_operation_steps_status_check;

alter table public.operator_operation_steps
  add constraint operator_operation_steps_status_check check (
    status in (
      'CREATED',
      'AWAITING_SIGNATURE',
      'BROADCASTED',
      'RUNNING',
      'CONFIRMED',
      'SUCCEEDED',
      'FAILED',
      'CANCELLED'
    )
  );

