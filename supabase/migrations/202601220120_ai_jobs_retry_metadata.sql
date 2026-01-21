-- AI Coach: job retry metadata + attempt counting

alter table public.ai_jobs
  add column if not exists attempt_count int not null default 0,
  add column if not exists last_error text,
  add column if not exists last_error_at timestamptz,
  add column if not exists last_error_code text,
  add column if not exists completed_at timestamptz;

create index if not exists ai_jobs_status_updated_at_idx
  on public.ai_jobs (status, updated_at);

create or replace function public.claim_ai_jobs(
  p_worker_id text,
  p_limit int default 1,
  p_kinds text[] default null
)
returns setof public.ai_jobs
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
    select j.id
    from public.ai_jobs j
    where j.status = 'queued'
      and j.run_after <= now()
      and (j.locked_at is null or j.locked_at < now() - interval '10 minutes')
      and (p_kinds is null or j.kind = any (p_kinds))
    order by j.run_after asc, j.created_at asc
    for update skip locked
    limit p_limit
  ),
  updated as (
    update public.ai_jobs j
    set status = 'running',
        locked_at = now(),
        locked_by = p_worker_id,
        updated_at = now(),
        attempt_count = coalesce(j.attempt_count, 0) + 1
    where j.id in (select id from candidate)
    returning j.*
  )
  select * from updated;
end;
$$;
