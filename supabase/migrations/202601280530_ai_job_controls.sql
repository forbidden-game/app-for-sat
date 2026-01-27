-- AI job controls + status summary

create table if not exists public.ai_job_controls (
  kind text primary key
    check (kind in (
      'attempt_insight',
      'thread_summary',
      'procedure_merge',
      'coach_reply',
      'snapshot_refresh',
      'progress_report',
      'english_grammar_analysis'
    )),
  allow_enqueue boolean not null default true,
  allow_process boolean not null default true,
  updated_at timestamptz default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.ai_job_controls enable row level security;

drop policy if exists ai_job_controls_service_only on public.ai_job_controls;
create policy ai_job_controls_service_only on public.ai_job_controls
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

insert into public.ai_job_controls (kind, allow_enqueue, allow_process)
values
  ('attempt_insight', true, true),
  ('thread_summary', true, true),
  ('procedure_merge', true, true),
  ('coach_reply', true, true),
  ('snapshot_refresh', true, true),
  ('progress_report', true, true),
  ('english_grammar_analysis', true, true)
on conflict (kind) do nothing;

create or replace function public.get_ai_job_status_summary()
returns table (
  kind text,
  queued_count int,
  running_count int,
  error_count int,
  last_updated_at timestamptz,
  last_success_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  select
    j.kind,
    count(*) filter (where j.status = 'queued')::int,
    count(*) filter (where j.status = 'running')::int,
    count(*) filter (where j.status = 'error')::int,
    max(j.updated_at) as last_updated_at,
    max(j.updated_at) filter (where j.status = 'done') as last_success_at
  from public.ai_jobs j
  group by j.kind;
end;
$$;
