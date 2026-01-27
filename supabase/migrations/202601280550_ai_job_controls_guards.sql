-- Guard enqueues with ai_job_controls and use configured prompt versions

create or replace function public.enqueue_attempt_insight_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allow boolean := true;
begin
  select allow_enqueue
    into v_allow
    from public.ai_job_controls
    where kind = 'attempt_insight';

  if coalesce(v_allow, true) is false then
    return new;
  end if;

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

create or replace function public.request_english_grammar_analysis(
  p_question_id uuid,
  p_student_id uuid default null
)
returns table (question_id uuid, status text, prompt_version text, updated_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question record;
  v_text_hash text;
  v_now timestamptz := now();
  v_student uuid;
  v_status text;
  v_prompt_version text := 'english-grammar-v2';
  v_allow_enqueue boolean := true;
begin
  select id, subject, stem
  into v_question
  from public.questions
  where id = p_question_id;

  if v_question.id is null then
    raise exception 'question_not_found';
  end if;

  if v_question.subject is null or v_question.subject <> 'reading' then
    raise exception 'unsupported_subject';
  end if;

  select allow_enqueue
    into v_allow_enqueue
    from public.ai_job_controls
    where kind = 'english_grammar_analysis';

  select prompt_version
    into v_prompt_version
    from public.ai_prompt_configs
    where kind = 'english_grammar_analysis'
      and status = 'published'
    order by created_at desc
    limit 1;

  if v_prompt_version is null or length(v_prompt_version) = 0 then
    v_prompt_version := 'english-grammar-v2';
  end if;

  v_text_hash := public.english_grammar_text_hash(v_question.stem);
  v_student := coalesce(p_student_id, auth.uid());

  insert into public.english_grammar_analyses (
    question_id,
    text_hash,
    prompt_version,
    status,
    created_at,
    updated_at
  )
  values (p_question_id, v_text_hash, v_prompt_version, 'queued', v_now, v_now)
  on conflict on constraint english_grammar_analyses_pkey do update
    set status = case
        when public.english_grammar_analyses.status = 'done' then 'done'
        when public.english_grammar_analyses.status = 'running' then 'running'
        else 'queued'
      end,
      updated_at = v_now;

  select ega.status
  into v_status
  from public.english_grammar_analyses ega
  where ega.question_id = p_question_id
    and ega.text_hash = v_text_hash
    and ega.prompt_version = v_prompt_version;

  if v_status <> 'done' then
    if coalesce(v_allow_enqueue, true) then
      insert into public.ai_jobs (
        kind,
        status,
        attempt_id,
        student_id,
        payload,
        dedupe_key
      )
      values (
        'english_grammar_analysis',
        'queued',
        null,
        v_student,
        jsonb_build_object(
          'question_id', p_question_id,
          'text_hash', v_text_hash,
          'prompt_version', v_prompt_version
        ),
        'english_grammar_analysis:' || p_question_id::text || ':' || v_text_hash || ':' || v_prompt_version
      )
      on conflict do nothing;
    else
      update public.english_grammar_analyses
        set status = 'error',
            error = 'enqueue_disabled',
            updated_at = v_now
        where question_id = p_question_id
          and text_hash = v_text_hash
          and prompt_version = v_prompt_version;
    end if;
  end if;

  return query
  select ega.question_id, ega.status, ega.prompt_version, ega.updated_at
  from public.english_grammar_analyses ega
  where ega.question_id = p_question_id
    and ega.text_hash = v_text_hash
    and ega.prompt_version = v_prompt_version;
end;
$$;

grant execute on function public.request_english_grammar_analysis(uuid, uuid) to authenticated;
