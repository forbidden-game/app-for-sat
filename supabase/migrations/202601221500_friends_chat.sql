-- Friends + 1:1 chat + invite code + push enqueue (MVP)

-- Tables

create table if not exists public.friend_invite_codes (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  code text not null unique,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.friend_dm_threads (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid not null references public.profiles(id) on delete cascade,
  user2_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  check (user1_id <> user2_id),
  -- Store ordered pair to guarantee uniqueness regardless of insertion order.
  check (user1_id < user2_id),
  unique (user1_id, user2_id)
);

create table if not exists public.friend_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.friend_dm_threads(id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz default now(),
  check (char_length(content) <= 2000)
);

create index if not exists friend_invite_codes_code_idx
  on public.friend_invite_codes (code);

create index if not exists friend_dm_threads_user1_idx
  on public.friend_dm_threads (user1_id);

create index if not exists friend_dm_threads_user2_idx
  on public.friend_dm_threads (user2_id);

create index if not exists friend_messages_thread_created_at_idx
  on public.friend_messages (thread_id, created_at desc);

-- RLS

alter table public.friend_invite_codes enable row level security;
alter table public.friend_dm_threads enable row level security;
alter table public.friend_messages enable row level security;

-- friend_invite_codes: only owner (or service) can read; writes via RPC

drop policy if exists friend_invite_codes_read_own on public.friend_invite_codes;
create policy friend_invite_codes_read_own on public.friend_invite_codes
  for select using (owner_id = auth.uid() or auth.role() = 'service_role');

-- friend_dm_threads: members can read; service role can do all

drop policy if exists friend_dm_threads_read_member on public.friend_dm_threads;
create policy friend_dm_threads_read_member on public.friend_dm_threads
  for select using (
    user1_id = auth.uid()
    or user2_id = auth.uid()
    or auth.role() = 'service_role'
  );

drop policy if exists friend_dm_threads_write_service on public.friend_dm_threads;
create policy friend_dm_threads_write_service on public.friend_dm_threads
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- friend_messages: thread members can read/write; sender must be auth.uid (except service)

drop policy if exists friend_messages_read_member on public.friend_messages;
create policy friend_messages_read_member on public.friend_messages
  for select using (
    auth.role() = 'service_role'
    or exists (
      select 1
      from public.friend_dm_threads t
      where t.id = friend_messages.thread_id
        and (t.user1_id = auth.uid() or t.user2_id = auth.uid())
    )
  );

drop policy if exists friend_messages_insert_member on public.friend_messages;
create policy friend_messages_insert_member on public.friend_messages
  for insert with check (
    auth.role() = 'service_role'
    or (
      sender_id = auth.uid()
      and exists (
        select 1
        from public.friend_dm_threads t
        where t.id = friend_messages.thread_id
          and (t.user1_id = auth.uid() or t.user2_id = auth.uid())
      )
    )
  );

-- Profiles: allow reading friend display_name via friend_dm_threads (keeps profiles non-searchable)

drop policy if exists profiles_read_friends on public.profiles;
create policy profiles_read_friends on public.profiles
  for select using (
    auth.role() = 'service_role'
    or exists (
      select 1
      from public.friend_dm_threads t
      where t.user1_id = least(auth.uid(), profiles.id)
        and t.user2_id = greatest(auth.uid(), profiles.id)
    )
  );

-- RPC: get my invite code (stable per user)

create or replace function public.get_my_friend_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_existing text;
  i int;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select code into v_existing
  from public.friend_invite_codes
  where owner_id = auth.uid();

  if v_existing is not null then
    return v_existing;
  end if;

  for i in 1..10 loop
    v_code := substr(encode(gen_random_bytes(8), 'hex'), 1, 12);
    begin
      insert into public.friend_invite_codes (owner_id, code)
      values (auth.uid(), v_code)
      on conflict (owner_id) do nothing;
      exit;
    exception
      when unique_violation then
        -- code collision (very unlikely), retry
        null;
    end;
  end loop;

  select code into v_existing
  from public.friend_invite_codes
  where owner_id = auth.uid();

  if v_existing is null then
    raise exception 'invite_code_generation_failed';
  end if;

  return v_existing;
end;
$$;

grant execute on function public.get_my_friend_invite_code() to authenticated;

-- RPC: redeem invite code => create/get DM thread

create or replace function public.redeem_friend_invite(invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_code text;
  v_owner_id uuid;
  v_user1 uuid;
  v_user2 uuid;
  v_thread_id uuid;
begin
  v_me := auth.uid();
  if v_me is null then
    raise exception 'unauthenticated';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_me and p.role = 'student'
  ) then
    raise exception 'not_student';
  end if;

  v_code := lower(trim(invite_code));
  if v_code is null or v_code = '' then
    raise exception 'invalid_invite_code';
  end if;

  select owner_id
  into v_owner_id
  from public.friend_invite_codes
  where code = v_code
  limit 1;

  if v_owner_id is null then
    raise exception 'invalid_invite_code';
  end if;

  if v_owner_id = v_me then
    raise exception 'cannot_add_self';
  end if;

  v_user1 := least(v_me, v_owner_id);
  v_user2 := greatest(v_me, v_owner_id);

  insert into public.friend_dm_threads (user1_id, user2_id)
  values (v_user1, v_user2)
  on conflict (user1_id, user2_id) do update
    set updated_at = now()
  returning id into v_thread_id;

  if v_thread_id is null then
    select id into v_thread_id
    from public.friend_dm_threads
    where user1_id = v_user1 and user2_id = v_user2;
  end if;

  return jsonb_build_object(
    'thread_id', v_thread_id,
    'friend_id', v_owner_id
  );
end;
$$;

grant execute on function public.redeem_friend_invite(text) to authenticated;

-- Friend threads list view (for iOS: friend_threads)
-- Columns: thread_id, friend_id, username, avatar_url, rating, last_message, last_seen

create or replace view public.friend_threads as
select
  t.id as thread_id,
  f.friend_id,
  coalesce(nullif(p.display_name, ''), 'User ' || substr(f.friend_id::text, 1, 8)) as username,
  null::text as avatar_url,
  null::int as rating,
  last_msg.content as last_message,
  coalesce(last_msg.created_at, t.created_at) as last_seen
from public.friend_dm_threads t
cross join lateral (
  select case when t.user1_id = auth.uid() then t.user2_id else t.user1_id end as friend_id
) f
join public.profiles p on p.id = f.friend_id
left join lateral (
  select m.content, m.created_at
  from public.friend_messages m
  where m.thread_id = t.id
  order by m.created_at desc
  limit 1
) last_msg on true
where t.user1_id = auth.uid() or t.user2_id = auth.uid();

-- Notification event_type: add friend_message_received

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_events_event_type_check'
      AND conrelid = 'public.notification_events'::regclass
  ) THEN
    ALTER TABLE public.notification_events
      DROP CONSTRAINT notification_events_event_type_check;
  END IF;

  ALTER TABLE public.notification_events
    ADD CONSTRAINT notification_events_event_type_check
    CHECK (event_type IN ('attempt_insight_ready','coach_reply_ready','friend_message_received'));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

-- Enqueue push notification outbox row when a friend message is inserted

create or replace function public.enqueue_friend_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user1 uuid;
  v_user2 uuid;
  v_recipient uuid;
  v_preview text;
begin
  select user1_id, user2_id
  into v_user1, v_user2
  from public.friend_dm_threads
  where id = new.thread_id;

  if v_user1 is null or v_user2 is null then
    return new;
  end if;

  if new.sender_id = v_user1 then
    v_recipient := v_user2;
  elsif new.sender_id = v_user2 then
    v_recipient := v_user1;
  else
    -- Sender not in thread; should be prevented by RLS, but avoid leaking notifications.
    return new;
  end if;

  v_preview := left(coalesce(new.content, ''), 120);

  insert into public.notification_events (student_id, event_type, payload, status)
  values (
    v_recipient,
    'friend_message_received',
    jsonb_build_object(
      'thread_id', new.thread_id,
      'message_id', new.id,
      'sender_id', new.sender_id,
      'preview', v_preview
    ),
    'queued'
  );

  return new;
end;
$$;

drop trigger if exists friend_messages_enqueue_notification on public.friend_messages;
create trigger friend_messages_enqueue_notification
after insert on public.friend_messages
for each row
execute function public.enqueue_friend_message_notification();

-- Realtime: enable insert streaming for friend_messages
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_messages;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;
  END IF;
END $$;
