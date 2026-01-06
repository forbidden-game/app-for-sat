-- Migration: Question CRUD Admin Support
-- Date: 2026-01-06
-- Description: 
--   1. Add question_types table for custom question types
--   2. Add is_admin() helper function for RLS
--   3. Update questions table constraint to support custom types
--   4. Add admin write policies for all question-related tables
--   5. Add question_assets extensions (storage_path, status)
--   6. Add reorder_bank_questions RPC
--   7. Add import_questions RPC for bulk import

-- ============================================
-- 1. question_types table
-- ============================================

create table if not exists public.question_types (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  display_name text not null,
  answer_schema jsonb not null default '{}'::jsonb,
  scoring_type text not null default 'exact' check (scoring_type in ('exact', 'partial', 'manual')),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Insert default question types
insert into public.question_types (name, display_name, answer_schema, scoring_type, sort_order) values
  ('mcq', 'Multiple Choice', '{"correct_field": "correct", "type": "single_choice"}', 'exact', 1),
  ('numeric', 'Numeric', '{"correct_field": "correct", "type": "number"}', 'exact', 2)
on conflict (name) do nothing;

-- ============================================
-- 2. is_admin() helper function
-- ============================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ============================================
-- 3. Update questions table constraint
-- ============================================

-- Remove old CHECK constraint (if exists)
alter table public.questions 
  drop constraint if exists questions_question_type_check;

-- Add foreign key to question_types
-- First ensure all existing question_types are in the table
insert into public.question_types (name, display_name, answer_schema, scoring_type, sort_order)
select distinct 
  question_type,
  initcap(replace(question_type, '_', ' ')),
  '{}'::jsonb,
  'exact',
  100
from public.questions
where question_type not in (select name from public.question_types)
on conflict (name) do nothing;

-- Now add the foreign key
alter table public.questions
  add constraint questions_type_fk 
  foreign key (question_type) references public.question_types(name);

-- ============================================
-- 4. Extend question_assets table
-- ============================================

alter table public.question_assets
  add column if not exists storage_path text,
  add column if not exists status text not null default 'active',
  add column if not exists created_by uuid references auth.users(id);

-- Add check constraint for status
alter table public.question_assets
  drop constraint if exists question_assets_status_check;
alter table public.question_assets
  add constraint question_assets_status_check 
  check (status in ('pending', 'active', 'deleted'));

-- Add index for cleanup job
create index if not exists question_assets_pending_idx 
  on public.question_assets(status, created_at) 
  where status = 'pending';

-- ============================================
-- 5. Add unique constraint to tags.name
-- ============================================

-- Ensure unique tag names (needed for bulk import upsert)
alter table public.tags
  drop constraint if exists tags_name_unique;

delete from public.tags t1
using public.tags t2
where t1.name = t2.name 
  and t1.id::text > t2.id::text;

alter table public.tags
  add constraint tags_name_unique unique (name);

-- ============================================
-- 6. Enable RLS on question_types
-- ============================================

alter table public.question_types enable row level security;

-- ============================================
-- 7. RLS Policies - Admin write access
-- ============================================

-- question_types: read for all authenticated, write for admin
create policy question_types_read on public.question_types
  for select using (auth.role() = 'authenticated');

create policy question_types_admin_write on public.question_types
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy question_types_admin_update on public.question_types
  for update using (is_admin() or auth.role() = 'service_role');

create policy question_types_admin_delete on public.question_types
  for delete using (is_admin() or auth.role() = 'service_role');

-- questions: replace read-only policy with full admin access
drop policy if exists questions_read_admin on public.questions;
drop policy if exists questions_admin_all on public.questions;

create policy questions_admin_select on public.questions
  for select using (is_admin() or auth.role() = 'service_role');

create policy questions_admin_insert on public.questions
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy questions_admin_update on public.questions
  for update using (is_admin() or auth.role() = 'service_role');

create policy questions_admin_delete on public.questions
  for delete using (is_admin() or auth.role() = 'service_role');

-- question_options: admin full access
drop policy if exists question_options_read on public.question_options;

create policy question_options_admin_select on public.question_options
  for select using (is_admin() or auth.role() = 'service_role');

create policy question_options_admin_insert on public.question_options
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy question_options_admin_update on public.question_options
  for update using (is_admin() or auth.role() = 'service_role');

create policy question_options_admin_delete on public.question_options
  for delete using (is_admin() or auth.role() = 'service_role');

-- tags: admin full access
drop policy if exists tags_read on public.tags;

create policy tags_admin_select on public.tags
  for select using (is_admin() or auth.role() = 'service_role');

create policy tags_admin_insert on public.tags
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy tags_admin_update on public.tags
  for update using (is_admin() or auth.role() = 'service_role');

create policy tags_admin_delete on public.tags
  for delete using (is_admin() or auth.role() = 'service_role');

-- question_tags: admin full access
drop policy if exists question_tags_read on public.question_tags;

create policy question_tags_admin_select on public.question_tags
  for select using (is_admin() or auth.role() = 'service_role');

create policy question_tags_admin_insert on public.question_tags
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy question_tags_admin_update on public.question_tags
  for update using (is_admin() or auth.role() = 'service_role');

create policy question_tags_admin_delete on public.question_tags
  for delete using (is_admin() or auth.role() = 'service_role');

-- question_assets: admin full access
drop policy if exists question_assets_read on public.question_assets;

create policy question_assets_admin_select on public.question_assets
  for select using (is_admin() or auth.role() = 'service_role');

create policy question_assets_admin_insert on public.question_assets
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy question_assets_admin_update on public.question_assets
  for update using (is_admin() or auth.role() = 'service_role');

create policy question_assets_admin_delete on public.question_assets
  for delete using (is_admin() or auth.role() = 'service_role');

-- question_bank_questions: admin full access
drop policy if exists question_bank_questions_read on public.question_bank_questions;

create policy question_bank_questions_admin_select on public.question_bank_questions
  for select using (is_admin() or auth.role() = 'service_role');

create policy question_bank_questions_admin_insert on public.question_bank_questions
  for insert with check (is_admin() or auth.role() = 'service_role');

create policy question_bank_questions_admin_update on public.question_bank_questions
  for update using (is_admin() or auth.role() = 'service_role');

create policy question_bank_questions_admin_delete on public.question_bank_questions
  for delete using (is_admin() or auth.role() = 'service_role');

-- ============================================
-- 8. reorder_bank_questions RPC
-- ============================================

create or replace function public.reorder_bank_questions(
  p_bank_id uuid,
  p_items jsonb  -- [{"question_id": "...", "position": 1}, ...]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'admin_required';
  end if;

  -- Temporarily disable unique constraint on position by using negative positions
  update question_bank_questions
  set position = -position - 1
  where bank_id = p_bank_id;

  -- Apply new positions
  update question_bank_questions qbq
  set position = (item->>'position')::int
  from jsonb_array_elements(p_items) item
  where qbq.bank_id = p_bank_id 
    and qbq.question_id = (item->>'question_id')::uuid;
end;
$$;

grant execute on function public.reorder_bank_questions(uuid, jsonb) to authenticated;

-- ============================================
-- 9. import_questions RPC for bulk import
-- ============================================

create or replace function public.import_questions(
  p_payload jsonb,
  p_partial boolean default false
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
begin
  -- Validate caller is admin
  if not is_admin() then
    raise exception 'admin_required';
  end if;

  for v_question in select * from jsonb_array_elements(p_payload->'questions')
  loop
    v_index := v_index + 1;
    begin
      -- Insert question
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

      -- Insert options
      insert into question_options (question_id, label, content)
      select v_question_id, opt->>'label', opt->>'content'
      from jsonb_array_elements(coalesce(v_question->'options', '[]'::jsonb)) opt
      where opt->>'label' is not null and opt->>'content' is not null;

      -- Handle tags (auto-create if not exists)
      insert into tags (name, category)
      select distinct 
        coalesce(t->>'name', t#>>'{}'),  -- Support both {name: "x"} and "x" formats
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

grant execute on function public.import_questions(jsonb, boolean) to authenticated;
