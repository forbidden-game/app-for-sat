alter table public.attempts
  add column if not exists client_submission_id uuid;

create unique index if not exists attempts_client_submission_id_uidx
  on public.attempts (client_submission_id)
  where client_submission_id is not null;

create or replace function public.get_session_result(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_session record;
  v_questions jsonb;
begin
  v_student_id := auth.uid();
  if v_student_id is null then
    raise exception 'unauthenticated';
  end if;

  select id, student_id, total_questions, correct_count
  into v_session
  from public.sessions
  where id = p_session_id;

  if v_session.id is null then
    raise exception 'session_not_found';
  end if;

  if v_session.student_id <> v_student_id then
    raise exception 'forbidden';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_id', sq.question_id,
        'attempt_id', att.id,
        'position', sq.position,
        'is_correct', coalesce(att.is_correct, false),
        'user_answer', case
          when att.id is null or att.skipped = true then null
          else att.answer
        end,
        'correct_answer', q.answer_key->'correct',
        'stem', q.stem,
        'options', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'label', o.label,
                'content', o.content
              )
              order by o.label
            )
            from public.question_options o
            where o.question_id = q.id
          ),
          '[]'::jsonb
        ),
        'explanation', coalesce(ae.content, '')
      )
      order by sq.position
    ),
    '[]'::jsonb
  )
  into v_questions
  from public.session_questions sq
  join public.questions q on q.id = sq.question_id
  left join lateral (
    select att.*
    from public.attempts att
    where att.session_id = p_session_id
      and att.question_id = sq.question_id
      and att.student_id = v_student_id
    order by att.created_at desc
    limit 1
  ) att on true
  left join public.ai_explanations ae on ae.question_id = sq.question_id
  where sq.session_id = p_session_id;

  return jsonb_build_object(
    'session_id', v_session.id,
    'total_questions', v_session.total_questions,
    'correct_count', v_session.correct_count,
    'questions', v_questions
  );
end;
$$;

grant execute on function public.get_session_result(uuid) to authenticated;
