# Implementation Notes

## Database
AI Coach uses the existing Supabase Postgres database.

Migrations added:
- `supabase/migrations/202601130520_ai_coach_mvp.sql`
- `supabase/migrations/202601130530_ai_coach_procedure_search.sql`
- `supabase/migrations/202601130610_ai_coach_chat.sql`
- `supabase/migrations/202601140200_ai_coach_reports.sql`
- `supabase/migrations/202601140320_notification_sender.sql`

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
  - `AI_COACH_MODEL_DEFAULT` (optional; defaults to `minimax/MiniMax-M2.1`)
  - `AI_COACH_MODEL_INSIGHT` / `AI_COACH_MODEL_CHAT` / `AI_COACH_MODEL_REPORT` (optional overrides)

Run:
- `cd ai-coach/coach-service`
- `npm install`
- `npm run dev`

Notes:
- Worker will periodically enqueue `snapshot_refresh` + `progress_report` jobs (interval via `AI_COACH_SCHEDULE_INTERVAL_MS`).

## Notification Sender
Location: `ai-coach/notification-sender/`

Setup:
- Copy `ai-coach/notification-sender/.env.example` to `ai-coach/notification-sender/.env`
- Fill:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

Run:
- `cd ai-coach/notification-sender`
- `npm install`
- `npm run dev`

## Edge Functions
- `submit_attempt`: scores + inserts an `attempts` row and returns `{ isCorrect, attemptId }`.
- `set_attempt_step`: updates `attempts.student_selected_step_*` after the student selects a step, and bumps `ai_jobs.run_after` to speed up processing.
- `coach_chat`: appends a user message to the per-student global coach thread and enqueues an `ai_jobs(kind='coach_reply')` job.

## Trigger
When a wrong attempt is inserted (`attempts.is_correct=false`), a job is enqueued automatically:
- `ai_jobs(kind='attempt_insight', status='queued', attempt_id=...)`

Chat messages also enqueue a job:
- `ai_jobs(kind='coach_reply', status='queued', student_id=...)`

The worker claims jobs via:
- `public.claim_ai_jobs(p_worker_id, p_limit)`

## iOS Flow (MVP)
- On submit: call `submit_attempt` and store `attemptId`.
- If wrong: show required step-selection sheet, then call `set_attempt_step` and poll `attempt_insights` for `explanation_short`.
- Coach Chat: open the chat view, call `coach_chat` to send messages, and subscribe to `coach_thread_messages` realtime insert/update events to render streaming assistant replies.

## Troubleshooting

### CI fails during `supabase db reset` with `generation expression is not immutable`
Symptom (GitHub Actions / local Supabase): migration fails with an error like:
- `ERROR: generation expression is not immutable (SQLSTATE 42P17)`

Cause:
- Postgres **generated columns** (`generated always as (...) stored`) require the expression to be **IMMUTABLE**.
- Some seemingly “pure” helpers (notably ones involving arrays / text normalization) are not marked immutable by Postgres.

Fix we use in AI Coach:
- Avoid generated columns for `procedures.search_text`.
- Store `search_text` as a normal column and maintain it via a `before insert/update` trigger.
- This keeps trigram search fast (`GIN ... gin_trgm_ops`) without violating immutability rules.
