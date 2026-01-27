-- Remove legacy prompt_version signature and keep a single request function

drop function if exists public.request_english_grammar_analysis(uuid, uuid, text);
drop function if exists public.request_english_grammar_analysis_v2(uuid, uuid);

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
  on conflict (question_id, text_hash, prompt_version) do update
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

create or replace function public.enqueue_daily_mix_english_grammar_analysis()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bank_mode text;
  v_student_id uuid;
  v_subject text;
begin
  select s.student_id, qb.mode
  into v_student_id, v_bank_mode
  from public.sessions s
  join public.question_banks qb on qb.id = s.bank_id
  where s.id = new.session_id;

  if v_bank_mode is null or v_bank_mode <> 'daily_mix' then
    return new;
  end if;

  select subject
  into v_subject
  from public.questions
  where id = new.question_id;

  if v_subject is null or v_subject <> 'reading' then
    return new;
  end if;

  perform public.request_english_grammar_analysis(new.question_id, v_student_id);

  return new;
end;
$$;
