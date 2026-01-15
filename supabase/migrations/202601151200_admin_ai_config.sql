-- Admin AI config + audit logs

create table if not exists public.ai_prompt_configs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('attempt_insight','coach_reply','progress_report')),
  prompt_version text not null,
  system_prompt text not null,
  model_provider text not null check (model_provider in ('minimax','openai')),
  model_id text not null,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  published_at timestamptz
);

create index if not exists ai_prompt_configs_kind_created_at_idx
  on public.ai_prompt_configs (kind, created_at desc);

create unique index if not exists ai_prompt_configs_kind_published_uidx
  on public.ai_prompt_configs (kind)
  where status = 'published';

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  actor_email text,
  action text not null,
  resource_type text not null,
  resource_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists admin_audit_logs_created_at_idx
  on public.admin_audit_logs (created_at desc);

create index if not exists admin_audit_logs_actor_idx
  on public.admin_audit_logs (actor_id, created_at desc);

alter table public.ai_prompt_configs enable row level security;
alter table public.admin_audit_logs enable row level security;

-- service role only

drop policy if exists ai_prompt_configs_service_only on public.ai_prompt_configs;
create policy ai_prompt_configs_service_only on public.ai_prompt_configs
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

drop policy if exists admin_audit_logs_service_only on public.admin_audit_logs;
create policy admin_audit_logs_service_only on public.admin_audit_logs
  for all using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- seed default published configs (minimax)
insert into public.ai_prompt_configs
  (kind, prompt_version, system_prompt, model_provider, model_id, status, created_at, updated_at, published_at)
values
  (
    'attempt_insight',
    'ai-coach-insight-v2',
    'You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.',
    'minimax',
    'MiniMax-M2.1',
    'published',
    now(),
    now(),
    now()
  ),
  (
    'coach_reply',
    'ai-coach-chat-v2',
    '你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。',
    'minimax',
    'MiniMax-M2.1',
    'published',
    now(),
    now(),
    now()
  ),
  (
    'progress_report',
    'ai-coach-report-v1',
    '你是严格、精要的 SAT 一对一老师，只输出 JSON。',
    'minimax',
    'MiniMax-M2.1',
    'published',
    now(),
    now(),
    now()
  )
on conflict do nothing;
