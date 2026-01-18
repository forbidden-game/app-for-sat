create or replace function public.get_session_history(
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_bank_id uuid default null,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_limit int;
begin
  v_student_id := auth.uid();
  if v_student_id is null then
    raise exception 'unauthenticated';
  end if;

  v_limit := coalesce(p_limit, 50);
  if v_limit < 1 then
    v_limit := 50;
  end if;
  if v_limit > 200 then
    v_limit := 200;
  end if;

  return (
    with sessions_filtered as (
      select
        s.id,
        s.created_at,
        s.total_questions,
        s.correct_count,
        s.bank_id,
        qb.title as bank_title
      from public.sessions s
      left join public.question_banks qb on qb.id = s.bank_id
      where s.student_id = v_student_id
        and (p_start is null or s.created_at >= p_start)
        and (p_end is null or s.created_at <= p_end)
        and (p_bank_id is null or s.bank_id = p_bank_id)
      order by s.created_at desc
      limit v_limit offset coalesce(p_offset, 0)
    ),
    attempt_stats as (
      select
        a.session_id,
        count(*) filter (where a.skipped is false and a.is_correct is not null) as attempts,
        count(*) filter (where a.skipped is false and a.is_correct is true) as correct,
        count(*) filter (where a.skipped is false and a.is_correct is false) as incorrect,
        sum(a.duration_ms) as duration_ms
      from public.attempts a
      join sessions_filtered s on s.id = a.session_id
      group by a.session_id
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'session_id', s.id,
          'created_at', s.created_at,
          'bank_id', s.bank_id,
          'bank_title', s.bank_title,
          'total_questions', s.total_questions,
          'correct_count', coalesce(ast.correct, s.correct_count),
          'attempts', coalesce(ast.attempts, 0),
          'incorrect_count', coalesce(ast.incorrect, 0),
          'duration_ms', coalesce(ast.duration_ms, 0)
        )
        order by s.created_at desc
      ),
      '[]'::jsonb
    )
    from sessions_filtered s
    left join attempt_stats ast on ast.session_id = s.id
  );
end;
$$;

grant execute on function public.get_session_history(timestamptz, timestamptz, uuid, int, int) to authenticated;
