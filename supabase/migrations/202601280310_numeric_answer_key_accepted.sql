-- Migration: Numeric answer_key accepted list
-- Date: 2026-01-28
--
-- Purpose:
-- - Document/encode that numeric questions can include multiple accepted answers in answer_key.
-- - This is used by the submit_attempt edge function for correct scoring.

update public.question_types
set answer_schema = jsonb_set(
  jsonb_set(answer_schema, '{accepted_field}', '"accepted"'::jsonb, true),
  '{tolerance}', '1e-9'::jsonb, true
)
where name = 'numeric';
