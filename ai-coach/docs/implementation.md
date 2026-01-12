# Implementation Notes

## Database
AI Coach uses the existing Supabase Postgres database.

Migrations added:
- `supabase/migrations/202601130520_ai_coach_mvp.sql`
- `supabase/migrations/202601130530_ai_coach_procedure_search.sql`

Local apply:
- `supabase start`
- `supabase db reset` (replays migrations + seed)

## Worker
Location: `ai-coach/coach-service/`

Setup:
- Copy `ai-coach/coach-service/.env.example` to `ai-coach/coach-service/.env`
- Fill:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `MINIMAX_API_KEY`

Run:
- `cd ai-coach/coach-service`
- `npm install`
- `npm run dev`

## Edge Functions
- `submit_attempt`: scores + inserts an `attempts` row and returns `{ isCorrect, attemptId }`.
- `set_attempt_step`: updates `attempts.student_selected_step_*` after the student selects a step, and bumps `ai_jobs.run_after` to speed up processing.

## Trigger
When a wrong attempt is inserted (`attempts.is_correct=false`), a job is enqueued automatically:
- `ai_jobs(kind='attempt_insight', status='queued', attempt_id=...)`

The worker claims jobs via:
- `public.claim_ai_jobs(p_worker_id, p_limit)`

## iOS Flow (MVP)
- On submit: call `submit_attempt` and store `attemptId`.
- If wrong: show required step-selection sheet, then call `set_attempt_step` and poll `attempt_insights` for `explanation_short`.
