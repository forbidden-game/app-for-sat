create extension if not exists pg_trgm;

-- attempts: student step selection (filled by iOS UI; MVP allows null)
alter table public.attempts
  add column if not exists student_selected_step_index int,
  add column if not exists student_selected_step_is_unknown boolean not null default false;

create table if not exists public.procedures (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  name text not null,
  description text,
  steps jsonb not null default '[]'::jsonb,
  steps_version int not null default 1,
  aliases text[] not null default '{}',
  status text not null default 'active' check (status in ('active','merged','deprecated')),
  merged_into uuid references public.procedures(id) on delete set null,
  created_by text not null default 'ai',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  search_text text not null default '',
  unique (subject, name)
);

create or replace function public.set_procedure_search_text()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.search_text := trim(
    coalesce(new.name, '') || ' ' || coalesce(array_to_string(new.aliases, ' '), '')
  );
  return new;
end;
$$;

drop trigger if exists procedures_set_search_text on public.procedures;
create trigger procedures_set_search_text
before insert or update of name, aliases on public.procedures
for each row
execute function public.set_procedure_search_text();

create index if not exists procedures_subject_status_idx
  on public.procedures (subject, status);

create index if not exists procedures_search_trgm_idx
  on public.procedures using gin (search_text gin_trgm_ops);

create table if not exists public.attempt_insights (
  attempt_id uuid primary key references public.attempts(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,

  procedure_id uuid not null references public.procedures(id) on delete restrict,
  procedure_steps_version int not null,

  error_step_index int not null,

  student_selected_step_index int,
  student_selected_step_is_unknown boolean not null default false,

  error_mode_enum text not null,
  error_mode_detail text,

  evidence jsonb not null default '{}'::jsonb,
  explanation_short text not null,
  followups jsonb not null default '[]'::jsonb,
  confidence numeric,

  model text,
  prompt_version text,
  cost_usd numeric,

  created_at timestamptz default now()
);

create index if not exists attempt_insights_student_procedure_step_idx
  on public.attempt_insights (student_id, procedure_id, error_step_index, created_at);

create index if not exists attempt_insights_student_created_at_idx
  on public.attempt_insights (student_id, created_at);

create table if not exists public.student_snapshots (
  student_id uuid primary key references public.profiles(id) on delete cascade,
  subject_scope text not null default 'all',
  weak_procedures_top jsonb not null default '[]'::jsonb,
  weak_steps_top jsonb not null default '[]'::jsonb,
  common_error_modes_top jsonb not null default '[]'::jsonb,
  recent_trend jsonb not null default '{}'::jsonb,
  notes text,
  updated_at timestamptz default now()
);

create table if not exists public.coach_thread_messages (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user','assistant','tool')),
  content jsonb not null,
  linked_attempt_id uuid references public.attempts(id) on delete set null,
  created_at timestamptz default now()
);

create index if not exists coach_thread_messages_student_created_at_idx
  on public.coach_thread_messages (student_id, created_at);

create table if not exists public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('attempt_insight','thread_summary','procedure_merge')),
  status text not null default 'queued' check (status in ('queued','running','done','error')),
  attempt_id uuid references public.attempts(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  error text,
  locked_at timestamptz,
  locked_by text,
  run_after timestamptz not null default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists ai_jobs_attempt_insight_unique
  on public.ai_jobs (attempt_id)
  where kind = 'attempt_insight';

create index if not exists ai_jobs_status_run_after_idx
  on public.ai_jobs (status, run_after);

alter table public.procedures enable row level security;
alter table public.attempt_insights enable row level security;
alter table public.student_snapshots enable row level security;
alter table public.coach_thread_messages enable row level security;
alter table public.ai_jobs enable row level security;

-- procedures: readable by authenticated (students) and service role
drop policy if exists procedures_read on public.procedures;
create policy procedures_read on public.procedures
  for select using (auth.role() = 'authenticated' or auth.role() = 'service_role');

-- attempt_insights: student can read own, service role can do all
drop policy if exists attempt_insights_read_own on public.attempt_insights;
create policy attempt_insights_read_own on public.attempt_insights
  for select using (student_id = auth.uid() or auth.role() = 'service_role');

drop policy if exists attempt_insights_write_service on public.attempt_insights;
create policy attempt_insights_write_service on public.attempt_insights
  for insert with check (auth.role() = 'service_role');

-- student_snapshots: student can read own, service role can write
drop policy if exists student_snapshots_read_own on public.student_snapshots;
create policy student_snapshots_read_own on public.student_snapshots
  for select using (student_id = auth.uid() or auth.role() = 'service_role');

drop policy if exists student_snapshots_write_service on public.student_snapshots;
create policy student_snapshots_write_service on public.student_snapshots
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- coach_thread_messages: student reads/writes own, service role can read
drop policy if exists coach_thread_messages_rw_own on public.coach_thread_messages;
create policy coach_thread_messages_rw_own on public.coach_thread_messages
  for all using (student_id = auth.uid() or auth.role() = 'service_role')
  with check (student_id = auth.uid() or auth.role() = 'service_role');

-- ai_jobs: service role only
drop policy if exists ai_jobs_service_only on public.ai_jobs;
create policy ai_jobs_service_only on public.ai_jobs
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create or replace function public.enqueue_attempt_insight_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_correct is true then
    return new;
  end if;

  if new.is_correct is null then
    return new;
  end if;

  insert into public.ai_jobs (kind, status, attempt_id, student_id, payload)
  values (
    'attempt_insight',
    'queued',
    new.id,
    new.student_id,
    jsonb_build_object('attempt_id', new.id)
  )
  on conflict (attempt_id) where kind = 'attempt_insight' do nothing;

  return new;
end;
$$;

drop trigger if exists attempts_enqueue_attempt_insight_job on public.attempts;
create trigger attempts_enqueue_attempt_insight_job
after insert on public.attempts
for each row
execute function public.enqueue_attempt_insight_job();

create or replace function public.claim_ai_jobs(
  p_worker_id text,
  p_limit int default 1
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

create or replace function public.get_attempt_for_coach(
  p_attempt_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt record;
  v_tags jsonb;
  v_options jsonb;
  v_question jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  select a.*
  into v_attempt
  from public.attempts a
  where a.id = p_attempt_id;

  if v_attempt.id is null then
    raise exception 'attempt_not_found';
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'category', t.category) order by t.category, t.name),
    '[]'::jsonb
  )
  into v_tags
  from public.question_tags qt
  join public.tags t on t.id = qt.tag_id
  where qt.question_id = v_attempt.question_id;

  select coalesce(
    jsonb_agg(jsonb_build_object('label', o.label, 'content', o.content) order by o.label),
    '[]'::jsonb
  )
  into v_options
  from public.question_options o
  where o.question_id = v_attempt.question_id;

  select jsonb_build_object(
    'id', q.id,
    'subject', q.subject,
    'module', q.module,
    'difficulty', q.difficulty,
    'question_type', q.question_type,
    'stem', q.stem,
    'answer_key', q.answer_key,
    'metadata', q.metadata,
    'options', v_options,
    'tags', v_tags
  )
  into v_question
  from public.questions q
  where q.id = v_attempt.question_id;

  return jsonb_build_object(
    'attempt', jsonb_build_object(
      'id', v_attempt.id,
      'student_id', v_attempt.student_id,
      'session_id', v_attempt.session_id,
      'question_id', v_attempt.question_id,
      'answer', v_attempt.answer,
      'is_correct', v_attempt.is_correct,
      'duration_ms', v_attempt.duration_ms,
      'skipped', v_attempt.skipped,
      'student_selected_step_index', v_attempt.student_selected_step_index,
      'student_selected_step_is_unknown', v_attempt.student_selected_step_is_unknown,
      'created_at', v_attempt.created_at
    ),
    'question', v_question
  );
end;
$$;
