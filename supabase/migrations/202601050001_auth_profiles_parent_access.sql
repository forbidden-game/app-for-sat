create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, display_name)
  values (new.id, 'student', null)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.parent_invite_codes (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete set null,
  code text not null unique,
  status text not null default 'active' check (status in ('active','redeemed','expired')),
  created_at timestamptz default now(),
  redeemed_at timestamptz,
  expires_at timestamptz
);

alter table public.parent_invite_codes enable row level security;

drop policy if exists "parent_invites_select_own" on public.parent_invite_codes;
drop policy if exists "parent_invites_insert_own" on public.parent_invite_codes;

create policy "parent_invites_select_own" on public.parent_invite_codes
  for select using (auth.uid() = parent_id);

create policy "parent_invites_insert_own" on public.parent_invite_codes
  for insert with check (auth.uid() = parent_id);

create or replace function public.create_parent_invite(expires_in_hours int default 168)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_is_parent boolean;
begin
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'parent'
  ) into v_is_parent;

  if not v_is_parent then
    raise exception 'not_parent';
  end if;

  v_code := substr(encode(gen_random_bytes(8), 'hex'), 1, 12);

  insert into public.parent_invite_codes (parent_id, code, expires_at)
  values (auth.uid(), v_code, now() + make_interval(hours => expires_in_hours));

  return v_code;
end;
$$;

create or replace function public.redeem_parent_invite(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_id uuid;
  v_is_student boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'student'
  ) into v_is_student;

  if not v_is_student then
    raise exception 'not_student';
  end if;

  select parent_id
  into v_parent_id
  from public.parent_invite_codes
  where code = invite_code
    and status = 'active'
    and (expires_at is null or expires_at > now())
  for update;

  if v_parent_id is null then
    raise exception 'invalid_invite_code';
  end if;

  insert into public.parent_student_links (parent_id, student_id, status)
  values (v_parent_id, auth.uid(), 'active')
  on conflict do nothing;

  update public.parent_invite_codes
  set status = 'redeemed', student_id = auth.uid(), redeemed_at = now()
  where code = invite_code;

  return v_parent_id;
end;
$$;

grant execute on function public.create_parent_invite(int) to authenticated;
grant execute on function public.redeem_parent_invite(text) to authenticated;

-- Parent read access to linked student data

drop policy if exists "parents_read_linked_sessions" on public.sessions;
create policy "parents_read_linked_sessions" on public.sessions
  for select using (
    exists (
      select 1 from public.parent_student_links l
      where l.parent_id = auth.uid()
        and l.student_id = sessions.student_id
        and l.status = 'active'
    )
  );

drop policy if exists "parents_read_linked_attempts" on public.attempts;
create policy "parents_read_linked_attempts" on public.attempts
  for select using (
    exists (
      select 1 from public.parent_student_links l
      where l.parent_id = auth.uid()
        and l.student_id = attempts.student_id
        and l.status = 'active'
    )
  );

-- Aggregate view for parent dashboards (uses underlying RLS)
create or replace view public.student_session_stats as
select
  student_id,
  count(*) as total_sessions,
  sum(total_questions) as total_questions,
  sum(correct_count) as total_correct,
  case when sum(total_questions) > 0
    then (sum(correct_count)::numeric / sum(total_questions))
    else null
  end as accuracy
from public.sessions
group by student_id;
