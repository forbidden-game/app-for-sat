create or replace function public.search_procedure_candidates(
  p_subject text,
  p_query text,
  p_limit int default 5
)
returns table (
  procedure_id uuid,
  name text,
  similarity float8,
  steps_version int,
  steps jsonb,
  description text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'forbidden';
  end if;

  return query
  select
    p.id,
    p.name,
    similarity(p.search_text, p_query) as similarity,
    p.steps_version,
    p.steps,
    p.description
  from public.procedures p
  where p.subject = p_subject
    and p.status = 'active'
  order by similarity desc
  limit p_limit;
end;
$$;
