# AI Coach Plan

## Product Goal
Build an “AI Coach” per student:
1) Wrong-answer coaching: short, strict step-based correction for SAT Math.
2) One global thread per student (“全科老师总线程”): cross-question chat with long-term learning state.

Key constraints:
- Similar-mistake key: `procedure_id + error_step_index` primary; `error_mode` secondary.
- iOS step selection required by default (with an “unknown” option).
- All new feature code/docs live under `ai-coach/`.

---

## Current Status

### Done (MVP: Wrong Attempt → Insight)
- [x] Supabase schema + RLS for AI Coach tables (`procedures`, `attempt_insights`, `student_snapshots`, `coach_thread_messages`, `ai_jobs`).
- [x] Job system: enqueue on wrong attempt, claim + process in worker.
- [x] Worker: tool-based agent writes `attempt_insights` + updates `student_snapshots`.
- [x] Edge functions:
  - [x] `submit_attempt` returns `{ isCorrect, attemptId }` and persists step selection if present.
  - [x] `set_attempt_step` updates step selection post-attempt and bumps `ai_jobs.run_after`.
- [x] iOS:
  - [x] `CoachStepSheet` required step selection + polling for `attempt_insights`.
  - [x] Practice flow integration: show coach sheet on wrong and advance on dismiss.

### Done (MVP: 全科老师总线程 Chat)
- [x] Migration `supabase/migrations/202601130610_ai_coach_chat.sql`:
  - [x] Allow `ai_jobs.kind = 'coach_reply'`.
  - [x] Add `coach_thread_messages` (and optional `attempt_insights`) to `supabase_realtime` publication.
- [x] Edge function `supabase/functions/coach_chat`:
  - [x] Verify JWT via `Authorization: Bearer <token>` using `auth.getUser`.
  - [x] Insert user message into `coach_thread_messages`.
  - [x] Enqueue `ai_jobs(kind='coach_reply')`.
- [x] Worker:
  - [x] Process `coach_reply` jobs.
  - [x] Insert assistant message with streaming status then update content incrementally (realtime-friendly).
- [x] iOS:
  - [x] `CoachChatView` + `CoachChatViewModel`.
  - [x] Realtime subscription (insert/update) on `coach_thread_messages` to render streaming replies.
  - [x] Entry point in side panel.

### Verified
- [x] Local: `swift test --package-path ios/StudentCore` passes.
- [x] Local: `xcodebuild ... build` passes.
- [x] CI: GitHub Actions `Test` green after chat + docs.

---

## Next Steps (prioritized)

### P0 — Connect “wrong attempt coaching” → “global thread chat”
- [ ] Add a CTA in `CoachStepSheet`: “Ask Coach” / “继续追问”.
- [ ] Send a message via `coach_chat` with `linked_attempt_id = attemptId` and a short structured prompt (e.g. “我卡在第 X 步，错因是什么？给我下一步训练题”).
- [ ] Open `CoachChatView` focused on the new message.

### P0 — Chat reliability + UX basics
- [ ] Initial history load (last N messages) before realtime subscription.
- [ ] Stable streaming UX: explicit `status`/`isStreaming` in assistant messages, stop conditions, and error fallback.
- [ ] Retry path for failed `coach_chat` calls (network/auth).

### P1 — Job hygiene (avoid spam + improve latency)
- [ ] Coalesce/merge `coach_reply` jobs per student (e.g., ignore queued replies if a newer user message exists).
- [ ] Add minimal rate limiting / cooldown to prevent runaway costs.

### P1 — Context management (thread summary)
- [ ] Implement `ai_jobs(kind='thread_summary')`:
  - [ ] Summarize older messages into a compact memory blob.
  - [ ] Ensure `coach_reply` prompt uses summary + recent messages + `student_snapshots`.

### P2 — Observability + ops
- [ ] Add structured logging fields: `job_id`, `student_id`, `attempt_id`.
- [ ] Track basic metrics (counts, latency, error rate) via DB columns or logs.

---

## Cloud End-to-End Validation (Supabase Cloud)
Prereq: the cloud project credentials are in `web/admin-dashboard/.env.local` (do not commit).

- [ ] Export env vars for local tools/tests:
  - [ ] `set -a; source web/admin-dashboard/.env.local; set +a`
- [ ] Ensure Edge Functions + migrations are deployed to the cloud project.
  - [ ] Recommended: `ENV_FILE=web/admin-dashboard/.env.local ai-coach/scripts/deploy-cloud.sh` (requires `supabase login` once).
- [ ] Run worker against cloud:
  - [ ] Create `ai-coach/coach-service/.env` with `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `MINIMAX_API_KEY`.
  - [ ] `cd ai-coach/coach-service && npm run dev`
- [ ] Run cloud E2E smoke tests (creates + cleans up temp data; use staging project):
  - [ ] `deno test --allow-env --allow-net ai-coach/tests/cloud-e2e/`
  - [x] Covered paths: `submit_attempt` job enqueue, `set_attempt_step` bump, `coach_chat` enqueue, `linked_attempt_id`.
- [ ] iOS manual flow: submit wrong attempt → choose step → see insight → tap “去问全科老师” → observe streaming reply in chat.

---

## Definition of Done (for next increment)
- The step sheet can deep-link into chat and include the attempt context (`linked_attempt_id`).
- Chat shows history + streaming without duplicates or missing updates.
- CI remains green.
