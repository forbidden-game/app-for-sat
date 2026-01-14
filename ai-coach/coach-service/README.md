# Coach Service (Worker)

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
- Model config is set in `src/config.ts`.
