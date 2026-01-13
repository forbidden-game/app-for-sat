-- AI Coach: notification outbox + push tokens + procedure service write

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  device_token text not null,
  platform text not null check (platform in ('apns','fcm')),
  last_seen_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (student_id, device_token)
);

create index if not exists push_tokens_student_idx
  on public.push_tokens (student_id, updated_at);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in ('attempt_insight_ready','coach_reply_ready')),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued','sent','error')),
  error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists notification_events_status_idx
  on public.notification_events (status, created_at);

alter table public.push_tokens enable row level security;
alter table public.notification_events enable row level security;

-- push_tokens: student owns their tokens, service role can manage

drop policy if exists push_tokens_rw_own on public.push_tokens;
create policy push_tokens_rw_own on public.push_tokens
  for all using (student_id = auth.uid() or auth.role() = 'service_role')
  with check (student_id = auth.uid() or auth.role() = 'service_role');

-- notification_events: service role only

drop policy if exists notification_events_service_only on public.notification_events;
create policy notification_events_service_only on public.notification_events
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- procedures: allow service role to insert/update generated procedures

drop policy if exists procedures_write_service on public.procedures;
create policy procedures_write_service on public.procedures
  for insert with check (auth.role() = 'service_role');

create policy procedures_update_service on public.procedures
  for update using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
