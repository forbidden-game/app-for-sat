-- AI provider keys + agent logs + openrouter support

alter table public.ai_prompt_configs
  drop constraint if exists ai_prompt_configs_model_provider_check;

alter table public.ai_prompt_configs
  add constraint ai_prompt_configs_model_provider_check
  check (model_provider in ('minimax','openai','openrouter'));

create table if not exists public.ai_provider_keys (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('openrouter')),
  api_key text not null,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists ai_provider_keys_provider_uidx
  on public.ai_provider_keys (provider);

create table if not exists public.ai_agent_logs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.ai_jobs(id) on delete set null,
  kind text not null,
  student_id uuid references public.profiles(id) on delete set null,
  attempt_id uuid references public.attempts(id) on delete set null,
  model_provider text not null,
  model_id text not null,
  prompt_version text,
  system_prompt text,
  prompts jsonb not null default '[]'::jsonb,
  events jsonb not null default '[]'::jsonb,
  status text not null check (status in ('done','error')),
  error text,
  created_at timestamptz default now()
);

create index if not exists ai_agent_logs_created_at_idx
  on public.ai_agent_logs (created_at desc);

create index if not exists ai_agent_logs_job_id_idx
  on public.ai_agent_logs (job_id);

create index if not exists ai_agent_logs_student_id_idx
  on public.ai_agent_logs (student_id, created_at desc);

alter table public.ai_provider_keys enable row level security;
alter table public.ai_agent_logs enable row level security;

drop policy if exists ai_provider_keys_service_only on public.ai_provider_keys;
create policy ai_provider_keys_service_only on public.ai_provider_keys
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

drop policy if exists ai_agent_logs_service_only on public.ai_agent_logs;
create policy ai_agent_logs_service_only on public.ai_agent_logs
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
