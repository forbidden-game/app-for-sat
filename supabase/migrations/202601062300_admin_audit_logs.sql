create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_audit_logs enable row level security;

drop policy if exists "admin_audit_logs_select" on public.admin_audit_logs;
drop policy if exists "admin_audit_logs_insert" on public.admin_audit_logs;

create policy "admin_audit_logs_select" on public.admin_audit_logs
  for select using (is_admin() or auth.role() = 'service_role');

create policy "admin_audit_logs_insert" on public.admin_audit_logs
  for insert with check (is_admin() or auth.role() = 'service_role');
