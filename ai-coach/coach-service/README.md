# Coach Service (Worker)
日期：2026-01-14

Purpose: power the per-student AI teacher (wrong-answer coaching + followups + long-term tracking).

Node/TypeScript worker that:
- claims `ai_jobs` of kind `attempt_insight`
- fetches attempt + question context
- uses `@mariozechner/pi-agent-core` + `@mariozechner/pi-ai` tool calling to:
  - reuse/create procedures
  - search similar mistakes for the student (procedure + step)
  - produce short, step-based coaching output
- writes `attempt_insights` and updates `student_snapshot`

## Env
Create `ai-coach/coach-service/.env` from `.env.example`.

## Run (local)
- `npm install`
- `npm run dev`

## Notes
- This worker expects Supabase URL + service role key.
- Model config defaults to env in `src/config.ts`, but published rows in `ai_prompt_configs` override prompt + model at runtime.
- OpenAI models require `OPENAI_API_KEY` (MiniMax uses `MINIMAX_API_KEY`).
