create table if not exists public.question_banks (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  subtitle text,
  icon text,
  mode text not null check (mode in ('fixed', 'daily_mix')),
  question_limit int not null default 10,
  rule_json jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.question_bank_questions (
  bank_id uuid references public.question_banks(id) on delete cascade,
  question_id uuid references public.questions(id) on delete cascade,
  position int not null,
  primary key (bank_id, question_id),
  unique (bank_id, position)
);

alter table public.sessions
  add column if not exists bank_id uuid references public.question_banks(id) on delete set null;

create table if not exists public.session_questions (
  session_id uuid references public.sessions(id) on delete cascade,
  question_id uuid references public.questions(id) on delete cascade,
  position int not null,
  assigned_at timestamptz default now(),
  primary key (session_id, question_id),
  unique (session_id, position)
);

create index if not exists question_banks_active_order_idx
  on public.question_banks (is_active, sort_order);

create index if not exists question_bank_questions_bank_position_idx
  on public.question_bank_questions (bank_id, position);

create index if not exists session_questions_session_position_idx
  on public.session_questions (session_id, position);

alter table public.question_banks enable row level security;
alter table public.question_bank_questions enable row level security;
alter table public.session_questions enable row level security;

drop policy if exists question_banks_read on public.question_banks;
create policy question_banks_read on public.question_banks
  for select using (auth.role() = 'authenticated' or auth.role() = 'service_role');

drop policy if exists question_bank_questions_read on public.question_bank_questions;
create policy question_bank_questions_read on public.question_bank_questions
  for select using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
    or auth.role() = 'service_role'
  );

drop policy if exists session_questions_read_own on public.session_questions;
create policy session_questions_read_own on public.session_questions
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = session_questions.session_id
        and s.student_id = auth.uid()
    )
  );

drop policy if exists questions_read on public.questions;
create policy questions_read_admin on public.questions
  for select using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
    or auth.role() = 'service_role'
  );

create or replace function public.start_practice_session(
  bank_slug text,
  override_limit int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_bank record;
  v_limit int;
  v_session_id uuid;
  v_total int;
  v_questions jsonb;
  v_subjects text[];
  v_modules text[];
  v_difficulties int[];
  v_tag_ids uuid[];
begin
  v_student_id := auth.uid();
  if v_student_id is null then
    raise exception 'unauthenticated';
  end if;

  select *
  into v_bank
  from public.question_banks
  where slug = bank_slug and is_active = true;

  if v_bank.id is null then
    raise exception 'bank_not_found';
  end if;

  v_limit := coalesce(override_limit, v_bank.question_limit, 10);
  if v_limit < 1 then
    raise exception 'invalid_limit';
  end if;

  insert into public.sessions (student_id, mode, total_questions, correct_count, bank_id)
  values (v_student_id, 'practice', v_limit, 0, v_bank.id)
  returning id into v_session_id;

  if v_bank.mode = 'fixed' then
    with selected as (
      select
        bq.question_id,
        row_number() over (order by bq.position asc) as position
      from public.question_bank_questions bq
      where bq.bank_id = v_bank.id
      order by bq.position asc
      limit v_limit
    ),
    inserted as (
      insert into public.session_questions (session_id, question_id, position)
      select v_session_id, question_id, position
      from selected
      returning question_id, position
    )
    select
      count(*)::int,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', q.id,
            'subject', q.subject,
            'module', q.module,
            'difficulty', q.difficulty,
            'question_type', q.question_type,
            'stem', q.stem,
            'metadata', q.metadata,
            'options', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', o.id,
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
            'assets', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', a.id,
                    'asset_url', a.asset_url,
                    'asset_type', a.asset_type
                  )
                  order by a.created_at
                )
                from public.question_assets a
                where a.question_id = q.id
              ),
              '[]'::jsonb
            )
          )
          order by inserted.position
        ),
        '[]'::jsonb
      )
    into v_total, v_questions
    from inserted
    join public.questions q on q.id = inserted.question_id;
  else
    v_subjects := coalesce(
      (
        select array_agg(value)
        from jsonb_array_elements_text(v_bank.rule_json->'subjects') as value
      ),
      '{}'
    );
    v_modules := coalesce(
      (
        select array_agg(value)
        from jsonb_array_elements_text(v_bank.rule_json->'modules') as value
      ),
      '{}'
    );
    v_difficulties := coalesce(
      (
        select array_agg(value::int)
        from jsonb_array_elements_text(v_bank.rule_json->'difficulties') as value
      ),
      '{}'
    );
    v_tag_ids := coalesce(
      (
        select array_agg(value::uuid)
        from jsonb_array_elements_text(v_bank.rule_json->'tag_ids') as value
      ),
      '{}'
    );

    with filtered as (
      select q.id
      from public.questions q
      where (cardinality(v_subjects) = 0 or q.subject = any (v_subjects))
        and (cardinality(v_modules) = 0 or q.module = any (v_modules))
        and (cardinality(v_difficulties) = 0 or q.difficulty = any (v_difficulties))
        and (
          cardinality(v_tag_ids) = 0
          or exists (
            select 1
            from public.question_tags qt
            where qt.question_id = q.id
              and qt.tag_id = any (v_tag_ids)
          )
        )
    ),
    ordered as (
      select
        f.id as question_id,
        row_number() over (
          order by md5(f.id::text || v_student_id::text || current_date::text)
        ) as position
      from filtered f
    ),
    limited as (
      select *
      from ordered
      order by position
      limit v_limit
    ),
    inserted as (
      insert into public.session_questions (session_id, question_id, position)
      select v_session_id, question_id, position
      from limited
      returning question_id, position
    )
    select
      count(*)::int,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', q.id,
            'subject', q.subject,
            'module', q.module,
            'difficulty', q.difficulty,
            'question_type', q.question_type,
            'stem', q.stem,
            'metadata', q.metadata,
            'options', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', o.id,
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
            'assets', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', a.id,
                    'asset_url', a.asset_url,
                    'asset_type', a.asset_type
                  )
                  order by a.created_at
                )
                from public.question_assets a
                where a.question_id = q.id
              ),
              '[]'::jsonb
            )
          )
          order by inserted.position
        ),
        '[]'::jsonb
      )
    into v_total, v_questions
    from inserted
    join public.questions q on q.id = inserted.question_id;
  end if;

  if v_total is null or v_total = 0 then
    raise exception 'no_questions_available';
  end if;

  update public.sessions
  set total_questions = v_total
  where id = v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'bank', jsonb_build_object(
      'id', v_bank.id,
      'slug', v_bank.slug,
      'title', v_bank.title,
      'subtitle', v_bank.subtitle,
      'icon', v_bank.icon,
      'mode', v_bank.mode,
      'question_limit', v_bank.question_limit
    ),
    'total_questions', v_total,
    'questions', v_questions
  );
end;
$$;

grant execute on function public.start_practice_session(text, int) to authenticated;
