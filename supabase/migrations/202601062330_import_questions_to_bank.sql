-- 10. import_questions_to_bank RPC for bulk import with optional bank attachment

create or replace function public.import_questions_to_bank(
  p_payload jsonb,
  p_partial boolean default false,
  p_bank_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question jsonb;
  v_question_id uuid;
  v_inserted_ids uuid[] := '{}';
  v_errors jsonb := '[]'::jsonb;
  v_index int := 0;
  v_position int := 0;
begin
  if not is_admin() then
    raise exception 'admin_required';
  end if;

  if p_bank_id is not null then
    select coalesce(max(position), 0)
    into v_position
    from question_bank_questions
    where bank_id = p_bank_id;
  end if;

  for v_question in select * from jsonb_array_elements(p_payload->'questions')
  loop
    v_index := v_index + 1;
    begin
      insert into questions (subject, module, difficulty, question_type, stem, answer_key, metadata)
      values (
        v_question->>'subject',
        v_question->>'module',
        (v_question->>'difficulty')::int,
        v_question->>'question_type',
        v_question->>'stem',
        v_question->'answer_key',
        coalesce(v_question->'metadata', '{}'::jsonb)
      )
      returning id into v_question_id;

      v_inserted_ids := array_append(v_inserted_ids, v_question_id);

      insert into question_options (question_id, label, content)
      select v_question_id, opt->>'label', opt->>'content'
      from jsonb_array_elements(coalesce(v_question->'options', '[]'::jsonb)) opt
      where opt->>'label' is not null and opt->>'content' is not null;

      insert into tags (name, category)
      select distinct
        coalesce(t->>'name', t#>>'{}'),
        coalesce(t->>'category', 'general')
      from jsonb_array_elements(coalesce(v_question->'tags', '[]'::jsonb)) t
      where coalesce(t->>'name', t#>>'{}') is not null
      on conflict (name) do nothing;

      insert into question_tags (question_id, tag_id)
      select v_question_id, tags.id
      from tags
      join jsonb_array_elements(coalesce(v_question->'tags', '[]'::jsonb)) t
        on tags.name = coalesce(t->>'name', t#>>'{}')
      on conflict do nothing;

      if p_bank_id is not null then
        v_position := v_position + 1;
        insert into question_bank_questions (bank_id, question_id, position)
        values (p_bank_id, v_question_id, v_position);
      end if;
    exception when others then
      v_errors := v_errors || jsonb_build_object(
        'index', v_index,
        'error', sqlerrm
      );
      if not p_partial then
        raise;
      end if;
    end;
  end loop;

  return jsonb_build_object(
    'inserted_count', coalesce(array_length(v_inserted_ids, 1), 0),
    'inserted_ids', to_jsonb(v_inserted_ids),
    'error_count', jsonb_array_length(v_errors),
    'errors', v_errors
  );
end;
$$;

grant execute on function public.import_questions_to_bank(jsonb, boolean, uuid) to authenticated;
