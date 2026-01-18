-- Allow provider-specific API keys beyond OpenRouter.

alter table public.ai_provider_keys
  drop constraint if exists ai_provider_keys_provider_check;

alter table public.ai_provider_keys
  add constraint ai_provider_keys_provider_check
  check (provider in ('minimax','openai','openrouter'));
