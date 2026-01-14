-- Extend claim_ai_jobs to support filtering by job kinds (optional).
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
        updated_at = now()
    where j.id in (select id from candidate)
    returning j.*
  )
  select * from updated;
end;
$$;
