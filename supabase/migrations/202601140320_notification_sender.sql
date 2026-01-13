-- Notification sender support (claim + locking)

alter table public.notification_events
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by text;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_events_status_check'
      AND conrelid = 'public.notification_events'::regclass
  ) THEN
    ALTER TABLE public.notification_events
      DROP CONSTRAINT notification_events_status_check;
  END IF;

  ALTER TABLE public.notification_events
    ADD CONSTRAINT notification_events_status_check
    CHECK (status IN ('queued','sending','sent','error'));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

create index if not exists notification_events_status_updated_at_idx
  on public.notification_events (status, updated_at);

create or replace function public.claim_notification_events(
  p_worker_id text,
  p_limit int default 5
)
returns setof public.notification_events
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  with candidate as (
    select n.id
    from public.notification_events n
    where n.status = 'queued'
      or (n.status = 'sending' and n.updated_at < now() - interval '10 minutes')
    order by n.created_at asc
    for update skip locked
    limit p_limit
  ),
  updated as (
    update public.notification_events n
    set status = 'sending',
        locked_at = now(),
        locked_by = p_worker_id,
        updated_at = now()
    where n.id in (select id from candidate)
    returning n.*
  )
  select * from updated;
end;
$$;
