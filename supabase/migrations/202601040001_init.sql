create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('student','parent','admin')),
  display_name text,
  created_at timestamptz default now()
);

create table if not exists public.parent_student_links (
  parent_id uuid references public.profiles(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz default now(),
  primary key (parent_id, student_id)
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  module text not null,
  difficulty int not null,
  question_type text not null check (question_type in ('mcq','numeric')),
  stem text not null,
  answer_key jsonb not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.questions(id) on delete cascade,
  label text not null,
  content text not null
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null
);

create table if not exists public.question_tags (
  question_id uuid references public.questions(id) on delete cascade,
  tag_id uuid references public.tags(id) on delete cascade,
  primary key (question_id, tag_id)
);

create table if not exists public.question_assets (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.questions(id) on delete cascade,
  asset_url text not null,
  asset_type text not null,
  created_at timestamptz default now()
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.profiles(id) on delete cascade,
  mode text not null default 'practice',
  total_questions int not null default 0,
  correct_count int not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.sessions(id) on delete cascade,
  question_id uuid references public.questions(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  answer jsonb,
  is_correct boolean,
  duration_ms int,
  skipped boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.ai_explanations (
  question_id uuid primary key references public.questions(id) on delete cascade,
  content text not null,
  model text not null,
  prompt_version text not null,
  cost_usd numeric,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.tags enable row level security;
alter table public.question_tags enable row level security;
alter table public.question_assets enable row level security;
alter table public.sessions enable row level security;
alter table public.attempts enable row level security;
alter table public.ai_explanations enable row level security;

create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

create policy "questions_read" on public.questions
  for select using (auth.role() = 'authenticated');
create policy "question_options_read" on public.question_options
  for select using (auth.role() = 'authenticated');
create policy "tags_read" on public.tags
  for select using (auth.role() = 'authenticated');
create policy "question_tags_read" on public.question_tags
  for select using (auth.role() = 'authenticated');
create policy "question_assets_read" on public.question_assets
  for select using (auth.role() = 'authenticated');

create policy "sessions_student_rw" on public.sessions
  for all using (auth.uid() = student_id);
create policy "attempts_student_rw" on public.attempts
  for all using (auth.uid() = student_id);

create policy "parent_links_read" on public.parent_student_links
  for select using (auth.uid() = parent_id);

create policy "ai_explanations_read" on public.ai_explanations
  for select using (auth.role() = 'authenticated');
