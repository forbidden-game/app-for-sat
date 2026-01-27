-- Add english_grammar_analysis to ai_prompt_configs

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ai_prompt_configs_kind_check'
      AND conrelid = 'public.ai_prompt_configs'::regclass
  ) THEN
    ALTER TABLE public.ai_prompt_configs DROP CONSTRAINT ai_prompt_configs_kind_check;
  END IF;

  ALTER TABLE public.ai_prompt_configs
    ADD CONSTRAINT ai_prompt_configs_kind_check
    CHECK (kind in (
      'attempt_insight',
      'coach_reply',
      'progress_report',
      'english_grammar_analysis'
    ));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

insert into public.ai_prompt_configs
  (kind, prompt_version, system_prompt, model_provider, model_id, status, created_at, updated_at, published_at)
values
  (
    'english_grammar_analysis',
    'english-grammar-v2',
    'You are an expert English grammar analyst. Output only valid JSON per the schema.',
    'minimax',
    'MiniMax-M2.1',
    'published',
    now(),
    now(),
    now()
  )
on conflict do nothing;
