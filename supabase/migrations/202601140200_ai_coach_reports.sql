-- AI Coach v2: student reports, job kinds, notification types, period stats

create table if not exists public.student_reports (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  period_kind text not null check (period_kind in ('weekly','monthly')),
  period_key text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  metrics jsonb not null,
  delta jsonb not null,
  summary text not null,
  plan jsonb not null,
  model text,
  prompt_version text,
  cost_usd numeric,
  created_at timestamptz default now(),
  unique (student_id, period_key)
);

create index if not exists student_reports_student_created_at_idx
  on public.student_reports (student_id, created_at desc);

alter table public.student_reports enable row level security;

-- student_reports: student can read own, service role can write

drop policy if exists student_reports_read_own on public.student_reports;
create policy student_reports_read_own on public.student_reports
  for select using (student_id = auth.uid() or auth.role() = 'service_role');

drop policy if exists student_reports_write_service on public.student_reports;
create policy student_reports_write_service on public.student_reports
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

alter table public.ai_jobs
  add column if not exists dedupe_key text;

create unique index if not exists ai_jobs_kind_dedupe_key_unique
  on public.ai_jobs (kind, dedupe_key)
  where dedupe_key is not null;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ai_jobs_kind_check'
      AND conrelid = 'public.ai_jobs'::regclass
  ) THEN
    ALTER TABLE public.ai_jobs DROP CONSTRAINT ai_jobs_kind_check;
  END IF;

  ALTER TABLE public.ai_jobs
    ADD CONSTRAINT ai_jobs_kind_check
    CHECK (kind IN (
      'attempt_insight',
      'thread_summary',
      'procedure_merge',
      'coach_reply',
      'snapshot_refresh',
      'progress_report'
    ));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_events_event_type_check'
      AND conrelid = 'public.notification_events'::regclass
  ) THEN
    ALTER TABLE public.notification_events
      DROP CONSTRAINT notification_events_event_type_check;
  END IF;

  ALTER TABLE public.notification_events
    ADD CONSTRAINT notification_events_event_type_check
    CHECK (event_type IN (
      'attempt_insight_ready',
      'coach_reply_ready',
      'progress_report_ready'
    ));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

create or replace function public.get_student_period_stats(
  p_student_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_attempts int;
  v_correct_attempts int;
  v_skipped_attempts int;
  v_avg_duration_ms numeric;
  v_attempts jsonb;
  v_top_procedures jsonb;
  v_top_steps jsonb;
  v_top_error_modes jsonb;
  v_subject_coverage jsonb;
  v_tag_coverage jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if p_start is null or p_end is null or p_end <= p_start then
    raise exception 'invalid_period';
  end if;

  select
    count(*) filter (where a.skipped is false and a.is_correct is not null),
    count(*) filter (where a.skipped is false and a.is_correct is true),
    count(*) filter (where a.skipped is true),
    avg(a.duration_ms) filter (
      where a.skipped is false
        and a.is_correct is not null
        and a.duration_ms is not null
    )
  into v_total_attempts, v_correct_attempts, v_skipped_attempts, v_avg_duration_ms
  from public.attempts a
  where a.student_id = p_student_id
    and a.created_at >= p_start
    and a.created_at < p_end;

  v_attempts := jsonb_build_object(
    'total', coalesce(v_total_attempts, 0),
    'correct', coalesce(v_correct_attempts, 0),
    'accuracy', case when v_total_attempts > 0 then v_correct_attempts::numeric / v_total_attempts else null end,
    'avg_duration_ms', v_avg_duration_ms,
    'skipped', coalesce(v_skipped_attempts, 0)
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'procedure_id', procedure_id,
        'subject', subject,
        'name', name,
        'count', attempts
      )
      order by attempts desc
    ),
    '[]'::jsonb
  )
  into v_top_procedures
  from (
    select
      p.id as procedure_id,
      p.subject,
      p.name,
      count(*) as attempts
    from public.attempt_insights ai
    join public.procedures p on p.id = ai.procedure_id
    where ai.student_id = p_student_id
      and ai.created_at >= p_start
      and ai.created_at < p_end
    group by p.id, p.subject, p.name
    order by attempts desc
    limit 5
  ) ranked;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'procedure_id', procedure_id,
        'procedure_name', procedure_name,
        'step_index', step_index,
        'step_text', step_text,
        'count', attempts
      )
      order by attempts desc
    ),
    '[]'::jsonb
  )
  into v_top_steps
  from (
    select
      p.id as procedure_id,
      p.name as procedure_name,
      ai.error_step_index as step_index,
      p.steps ->> ai.error_step_index as step_text,
      count(*) as attempts
    from public.attempt_insights ai
    join public.procedures p on p.id = ai.procedure_id
    where ai.student_id = p_student_id
      and ai.created_at >= p_start
      and ai.created_at < p_end
    group by p.id, p.name, ai.error_step_index, p.steps
    order by attempts desc
    limit 5
  ) ranked;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'error_mode', error_mode,
        'count', attempts
      )
      order by attempts desc
    ),
    '[]'::jsonb
  )
  into v_top_error_modes
  from (
    select
      ai.error_mode_enum as error_mode,
      count(*) as attempts
    from public.attempt_insights ai
    where ai.student_id = p_student_id
      and ai.created_at >= p_start
      and ai.created_at < p_end
    group by ai.error_mode_enum
    order by attempts desc
    limit 5
  ) ranked;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'subject', subject,
        'attempts', attempts
      )
      order by attempts desc
    ),
    '[]'::jsonb
  )
  into v_subject_coverage
  from (
    select
      q.subject,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts
    from public.attempts a
    join public.questions q on q.id = a.question_id
    where a.student_id = p_student_id
      and a.created_at >= p_start
      and a.created_at < p_end
    group by q.subject
    order by attempts desc
  ) ranked;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'tag_id', tag_id,
        'tag_name', tag_name,
        'attempts', attempts
      )
      order by attempts desc
    ),
    '[]'::jsonb
  )
  into v_tag_coverage
  from (
    select
      t.id as tag_id,
      t.name as tag_name,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts
    from public.attempts a
    join public.question_tags qt on qt.question_id = a.question_id
    join public.tags t on t.id = qt.tag_id
    where a.student_id = p_student_id
      and a.created_at >= p_start
      and a.created_at < p_end
    group by t.id, t.name
    order by attempts desc
  ) ranked;

  return jsonb_build_object(
    'attempts', v_attempts,
    'mistakes', jsonb_build_object(
      'top_procedures', v_top_procedures,
      'top_steps', v_top_steps,
      'top_error_modes', v_top_error_modes
    ),
    'coverage', jsonb_build_object(
      'subjects', v_subject_coverage,
      'tags', v_tag_coverage
    )
  );
end;
$$;

create or replace function public.list_active_students(
  p_since timestamptz
)
returns table (student_id uuid)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  select distinct a.student_id
  from public.attempts a
  where a.created_at >= p_since;
end;
$$;
