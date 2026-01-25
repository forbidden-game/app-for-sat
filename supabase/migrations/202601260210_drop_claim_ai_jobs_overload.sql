-- Remove legacy overload to avoid ambiguity with defaulted p_kinds.
drop function if exists public.claim_ai_jobs(text, int);
