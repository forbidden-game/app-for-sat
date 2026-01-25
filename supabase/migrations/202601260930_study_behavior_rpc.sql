create or replace function public.get_study_behavior(
  target_student_id uuid,
  window_days int default 7,
  history_weeks int default 8
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requester uuid;
  v_target uuid;
  v_window_days int;
  v_history_weeks int;
  v_window_start timestamptz;
  v_prev_start timestamptz;
  v_attempts_cur int;
  v_correct_cur int;
  v_duration_ms_cur bigint;
  v_active_days_cur int;
  v_attempts_prev int;
  v_correct_prev int;
  v_duration_ms_prev bigint;
  v_active_days_prev int;
  v_accuracy_cur numeric;
  v_accuracy_prev numeric;
  v_accuracy_delta numeric;
  v_minutes_cur numeric;
  v_minutes_prev numeric;
  v_minutes_delta numeric;
  v_active_days_delta int;
  v_confidence numeric;
  v_state text;
  v_drivers jsonb;
  v_daily jsonb;
  v_weekly jsonb;
  v_accuracy_delta_text text;
  v_minutes_delta_text text;
  v_days_delta_text text;
begin
  if auth.role() = 'service_role' then
    if target_student_id is null then
      raise exception 'target_student_required';
    end if;
    v_target := target_student_id;
  else
    v_requester := auth.uid();
    if v_requester is null then
      raise exception 'unauthenticated';
    end if;

    v_target := coalesce(target_student_id, v_requester);

    if v_target <> v_requester then
      if not exists (
        select 1
        from public.parent_student_links l
        where l.parent_id = v_requester
          and l.student_id = v_target
          and l.status = 'active'
      ) and not public.is_admin() then
        raise exception 'not_authorized';
      end if;
    end if;
  end if;

  v_window_days := coalesce(window_days, 7);
  if v_window_days < 1 then
    v_window_days := 7;
  end if;
  if v_window_days > 60 then
    v_window_days := 60;
  end if;

  v_history_weeks := coalesce(history_weeks, 8);
  if v_history_weeks < 1 then
    v_history_weeks := 8;
  end if;
  if v_history_weeks > 26 then
    v_history_weeks := 26;
  end if;

  v_window_start := date_trunc('day', now()) - make_interval(days => v_window_days - 1);
  v_prev_start := v_window_start - make_interval(days => v_window_days);

  select
    count(*) filter (where a.skipped is false and a.is_correct is not null),
    count(*) filter (where a.skipped is false and a.is_correct is true),
    sum(a.duration_ms),
    count(distinct date(a.created_at))
  into v_attempts_cur, v_correct_cur, v_duration_ms_cur, v_active_days_cur
  from public.attempts a
  where a.student_id = v_target
    and a.created_at >= v_window_start;

  select
    count(*) filter (where a.skipped is false and a.is_correct is not null),
    count(*) filter (where a.skipped is false and a.is_correct is true),
    sum(a.duration_ms),
    count(distinct date(a.created_at))
  into v_attempts_prev, v_correct_prev, v_duration_ms_prev, v_active_days_prev
  from public.attempts a
  where a.student_id = v_target
    and a.created_at >= v_prev_start
    and a.created_at < v_window_start;

  v_attempts_cur := coalesce(v_attempts_cur, 0);
  v_correct_cur := coalesce(v_correct_cur, 0);
  v_duration_ms_cur := coalesce(v_duration_ms_cur, 0);
  v_active_days_cur := coalesce(v_active_days_cur, 0);
  v_attempts_prev := coalesce(v_attempts_prev, 0);
  v_correct_prev := coalesce(v_correct_prev, 0);
  v_duration_ms_prev := coalesce(v_duration_ms_prev, 0);
  v_active_days_prev := coalesce(v_active_days_prev, 0);

  v_accuracy_cur := case when v_attempts_cur > 0 then v_correct_cur::numeric / v_attempts_cur else null end;
  v_accuracy_prev := case when v_attempts_prev > 0 then v_correct_prev::numeric / v_attempts_prev else null end;
  v_accuracy_delta := case
    when v_accuracy_cur is null or v_accuracy_prev is null then null
    else v_accuracy_cur - v_accuracy_prev
  end;

  v_minutes_cur := round(coalesce(v_duration_ms_cur, 0)::numeric / 60000, 1);
  v_minutes_prev := round(coalesce(v_duration_ms_prev, 0)::numeric / 60000, 1);
  v_minutes_delta := v_minutes_cur - v_minutes_prev;
  v_active_days_delta := coalesce(v_active_days_cur, 0) - coalesce(v_active_days_prev, 0);

  v_confidence := case
    when v_attempts_cur >= 20 then 1
    when v_attempts_cur <= 0 then 0
    else round(v_attempts_cur::numeric / 20, 2)
  end;

  v_minutes_delta_text := case
    when v_minutes_delta >= 0 then format('+%.1f', v_minutes_delta)
    else format('%.1f', v_minutes_delta)
  end;

  v_days_delta_text := case
    when v_active_days_delta >= 0 then format('+%s', v_active_days_delta)
    else format('%s', v_active_days_delta)
  end;

  v_accuracy_delta_text := case
    when v_accuracy_delta is null then ''
    when v_accuracy_delta >= 0 then format('+%.0f%%', v_accuracy_delta * 100)
    else format('%.0f%%', v_accuracy_delta * 100)
  end;

  if v_attempts_cur = 0 then
    v_state := 'No Data';
  elsif v_active_days_cur >= greatest(3, floor(v_window_days * 0.6))
    and v_minutes_cur >= 60
    and (v_accuracy_delta is null or v_accuracy_delta >= 0) then
    v_state := 'On Track';
  elsif v_minutes_delta > 0
    or v_active_days_delta > 0
    or (v_accuracy_delta is not null and v_accuracy_delta > 0) then
    v_state := 'Catching Up';
  elsif v_active_days_cur <= 1
    or (v_minutes_delta < 0 and v_accuracy_delta is not null and v_accuracy_delta < -0.05) then
    v_state := 'At Risk';
  else
    v_state := 'Inconsistent';
  end if;

  v_drivers := jsonb_build_array(
    format('Time spent %.1f min (%s vs prior %sd)', v_minutes_cur, v_minutes_delta_text, v_window_days),
    case
      when v_accuracy_cur is null then 'Accuracy N/A'
      when v_accuracy_delta is null then format('Accuracy %.0f%%', v_accuracy_cur * 100)
      else format('Accuracy %.0f%% (%s vs prior %sd)', v_accuracy_cur * 100, v_accuracy_delta_text, v_window_days)
    end,
    format('Active days %s/%s (%s)', v_active_days_cur, v_window_days, v_days_delta_text)
  );

  with days as (
    select generate_series(
      date_trunc('day', now()) - make_interval(days => v_window_days - 1),
      date_trunc('day', now()),
      interval '1 day'
    )::date as day
  ),
  daily as (
    select
      date_trunc('day', a.created_at)::date as day,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
      count(*) filter (where a.skipped is false and a.is_correct is true) as correct,
      sum(a.duration_ms) as duration_ms
    from public.attempts a
    where a.student_id = v_target
      and a.created_at >= v_window_start
    group by 1
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'date', d.day,
        'minutes', round(coalesce(daily.duration_ms, 0)::numeric / 60000, 1),
        'attempts', coalesce(daily.attempts, 0),
        'accuracy',
          case when coalesce(daily.attempts, 0) > 0
            then daily.correct::numeric / daily.attempts
            else null
          end
      )
      order by d.day
    ),
    '[]'::jsonb
  )
  into v_daily
  from days d
  left join daily on daily.day = d.day;

  with weeks as (
    select generate_series(
      date_trunc('week', now()) - make_interval(weeks => v_history_weeks - 1),
      date_trunc('week', now()),
      interval '1 week'
    ) as week_start
  ),
  weekly as (
    select
      date_trunc('week', a.created_at) as week_start,
      count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
      count(*) filter (where a.skipped is false and a.is_correct is true) as correct,
      sum(a.duration_ms) as duration_ms,
      count(distinct date(a.created_at)) as active_days
    from public.attempts a
    where a.student_id = v_target
      and a.created_at >= date_trunc('week', now()) - make_interval(weeks => v_history_weeks - 1)
    group by 1
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'week_start', w.week_start::date,
        'minutes', round(coalesce(weekly.duration_ms, 0)::numeric / 60000, 1),
        'attempts', coalesce(weekly.attempts, 0),
        'accuracy',
          case when coalesce(weekly.attempts, 0) > 0
            then weekly.correct::numeric / weekly.attempts
            else null
          end,
        'active_days', coalesce(weekly.active_days, 0)
      )
      order by w.week_start
    ),
    '[]'::jsonb
  )
  into v_weekly
  from weeks w
  left join weekly on weekly.week_start = w.week_start;

  return jsonb_build_object(
    'student_id', v_target,
    'window_days', v_window_days,
    'state', jsonb_build_object(
      'label', v_state,
      'confidence', v_confidence
    ),
    'drivers', v_drivers,
    'metrics', jsonb_build_object(
      'minutes', v_minutes_cur,
      'minutes_delta', v_minutes_delta,
      'accuracy', v_accuracy_cur,
      'accuracy_delta', v_accuracy_delta,
      'active_days', v_active_days_cur,
      'active_days_delta', v_active_days_delta,
      'attempts', coalesce(v_attempts_cur, 0)
    ),
    'daily', v_daily,
    'weekly', v_weekly
  );
end;
$$;

grant execute on function public.get_study_behavior(uuid, int, int) to authenticated;
