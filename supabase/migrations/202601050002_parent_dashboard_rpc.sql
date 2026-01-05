create index if not exists attempts_student_created_at_idx
  on public.attempts (student_id, created_at);

create index if not exists sessions_student_created_at_idx
  on public.sessions (student_id, created_at);

create or replace function public.get_parent_dashboard(
  target_student_id uuid,
  window_days int default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_id uuid;
  v_student record;
  v_window_start timestamptz;
  v_attempts_7d int;
  v_correct_7d int;
  v_incorrect_7d int;
  v_duration_ms bigint;
  v_rank_percentile_raw numeric;
  v_rank_percentile numeric;
  v_overview jsonb;
  v_trend jsonb;
  v_topics jsonb;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  if window_days is null or window_days < 1 then
    window_days := 7;
  end if;

  v_parent_id := auth.uid();

  if not exists (
    select 1
    from public.parent_student_links l
    where l.parent_id = v_parent_id
      and l.student_id = target_student_id
      and l.status = 'active'
  ) then
    raise exception 'not_authorized';
  end if;

  select p.id, p.display_name
  into v_student
  from public.profiles p
  where p.id = target_student_id;

  if v_student.id is null then
    raise exception 'student_not_found';
  end if;

  v_window_start := now() - make_interval(days => window_days);

  select
    count(*) filter (where a.skipped is false and a.is_correct is not null),
    count(*) filter (where a.skipped is false and a.is_correct is true),
    count(*) filter (where a.skipped is false and a.is_correct is false),
    sum(a.duration_ms)
  into v_attempts_7d, v_correct_7d, v_incorrect_7d, v_duration_ms
  from public.attempts a
  where a.student_id = target_student_id
    and a.created_at >= v_window_start;

  with student_attempts as (
    select
      a.student_id,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
      count(*) filter (where a.skipped is false and a.is_correct is true) as correct
    from public.attempts a
    where a.created_at >= v_window_start
    group by a.student_id
  ),
  eligible as (
    select
      student_id,
      attempts,
      correct,
      case when attempts > 0 then correct::numeric / attempts else null end as accuracy
    from student_attempts
    where attempts >= 20
  ),
  ranked as (
    select
      student_id,
      accuracy,
      rank() over (order by accuracy asc) as rnk,
      count(*) over () as total
    from eligible
  )
  select
    case when r.total > 0 then r.rnk::numeric / r.total else null end
  into v_rank_percentile_raw
  from ranked r
  where r.student_id = target_student_id;

  if v_attempts_7d is not null and v_attempts_7d >= 20 then
    v_rank_percentile := v_rank_percentile_raw;
  else
    v_rank_percentile := null;
  end if;

  v_overview := jsonb_build_object(
    'window_days', window_days,
    'practice_minutes', round(coalesce(v_duration_ms, 0)::numeric / 60000, 1),
    'accuracy', case when v_attempts_7d > 0 then v_correct_7d::numeric / v_attempts_7d else null end,
    'error_rate', case when v_attempts_7d > 0 then v_incorrect_7d::numeric / v_attempts_7d else null end,
    'rank_percentile', v_rank_percentile,
    'attempts', coalesce(v_attempts_7d, 0)
  );

  with last_sessions as (
    select s.id, s.created_at
    from public.sessions s
    where s.student_id = target_student_id
    order by s.created_at desc
    limit 5
  ),
  session_stats as (
    select
      ls.id as session_id,
      ls.created_at,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
      count(*) filter (where a.skipped is false and a.is_correct is true) as correct,
      sum(a.duration_ms) as duration_ms
    from last_sessions ls
    left join public.attempts a
      on a.session_id = ls.id
    group by ls.id, ls.created_at
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'session_id', session_id,
        'created_at', created_at,
        'accuracy', case when attempts > 0 then correct::numeric / attempts else null end,
        'rank_percentile', v_rank_percentile,
        'attempts', coalesce(attempts, 0),
        'duration_minutes', round(coalesce(duration_ms, 0)::numeric / 60000, 1)
      )
      order by created_at desc
    ),
    '[]'::jsonb
  )
  into v_trend
  from session_stats;

  with tag_stats as (
    select
      t.id as tag_id,
      t.name as tag_name,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
      count(*) filter (where a.skipped is false and a.is_correct is true) as correct
    from public.attempts a
    join public.question_tags qt on qt.question_id = a.question_id
    join public.tags t on t.id = qt.tag_id
    where a.student_id = target_student_id
      and a.created_at >= v_window_start
    group by t.id, t.name
    having count(*) filter (where a.skipped is false and a.is_correct is not null) >= 10
  ),
  tag_scored as (
    select
      tag_id,
      tag_name,
      attempts,
      case when attempts > 0 then correct::numeric / attempts else null end as accuracy
    from tag_stats
  ),
  top_tags as (
    select *, 1 as priority
    from tag_scored
    order by accuracy desc nulls last
    limit 3
  ),
  bottom_tags as (
    select *, 2 as priority
    from tag_scored
    order by accuracy asc nulls last
    limit 3
  ),
  combined as (
    select * from top_tags
    union all
    select * from bottom_tags
  ),
  deduped as (
    select distinct on (tag_id)
      tag_id,
      tag_name,
      accuracy,
      attempts,
      priority
    from combined
    order by tag_id, priority
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'tag_id', tag_id,
        'tag_name', tag_name,
        'accuracy', accuracy,
        'attempts', attempts
      )
      order by priority, accuracy desc nulls last
    ),
    '[]'::jsonb
  )
  into v_topics
  from deduped;

  return jsonb_build_object(
    'student', jsonb_build_object(
      'id', v_student.id,
      'name', coalesce(v_student.display_name, ''),
      'grade', ''
    ),
    'overview', v_overview,
    'trend', v_trend,
    'topics', v_topics
  );
end;
$$;

grant execute on function public.get_parent_dashboard(uuid, int) to authenticated;
