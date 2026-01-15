-- AI Coach memory entries (daily + curated)

create table if not exists public.coach_memory_entries (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null check (scope in ('daily','curated')),
  content text not null,
  tags text[] default '{}'::text[],
  source text,
  created_at timestamptz default now()
);

create index if not exists coach_memory_entries_student_created_at_idx
  on public.coach_memory_entries (student_id, created_at desc);

create index if not exists coach_memory_entries_scope_idx
  on public.coach_memory_entries (scope);

alter table public.coach_memory_entries enable row level security;

-- student can read own; service role can write

drop policy if exists coach_memory_entries_read_own on public.coach_memory_entries;
create policy coach_memory_entries_read_own on public.coach_memory_entries
  for select using (auth.uid() = student_id);

drop policy if exists coach_memory_entries_write_service on public.coach_memory_entries;
create policy coach_memory_entries_write_service on public.coach_memory_entries
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
