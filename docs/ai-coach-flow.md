---
summary: AI Coach backend pipeline draft and worker flow
read_when: updating AI coach backend flow, Edge Functions, or workers
---

# AI Coach Backend Flow (Draft)
日期：2026-01-15

## North Star
Per-student AI teacher: immediate wrong-answer coaching, multi-turn followups, long-term learning tracking. This flow exists to power that teacher.

## Overview
This document describes the current backend draft for the AI coach pipeline and how it connects to the iOS app. The implementation is intentionally stubbed: it provides deterministic placeholder outputs so the front end can be exercised while the real model integration is built.

## iOS Entry Points
- `submit_attempt` Edge Function
  - Inserts `attempts` rows and returns `{ isCorrect, attemptId }`.
  - The insert trigger enqueues `ai_jobs(kind='attempt_insight')` for incorrect answers.
- `set_attempt_step` Edge Function
  - Saves student-selected step information on the attempt.
  - Requeues the `attempt_insight` job regardless of its prior status.
- `coach_chat` Edge Function
  - Inserts a user message into `coach_thread_messages`.
  - Enqueues `ai_jobs(kind='coach_reply')`.
- `attempt_insights` table
  - iOS polls `attempt_insights` by `attempt_id` for the short explanation and followups.

## Worker Flow (process_ai_jobs)
The draft worker runs as an Edge Function (`supabase/functions/process_ai_jobs`) and must be called with a worker secret.

### Job Processing
- Claims jobs via `claim_ai_jobs` (service role only).
- Handles kinds:
  - `attempt_insight`
    - Calls `get_attempt_for_coach` for full attempt + question context.
    - Builds a draft insight with `buildAttemptInsightDraft`.
    - Ensures a fallback `procedures` row exists for the subject.
    - Upserts `attempt_insights` (overwrites when re-queued).
    - Inserts a `notification_events` row (`attempt_insight_ready`).
  - `coach_reply`
    - Reads the user message from `coach_thread_messages`.
    - Builds a draft reply via `buildCoachReplyDraft`.
    - Inserts an assistant message with `status: "streaming"`, then updates it in a few chunks.
    - Inserts a `notification_events` row (`coach_reply_ready`).
  - `snapshot_refresh`
    - Calls `get_student_period_stats` (7/30/90 days) and updates `student_snapshots`.
  - `progress_report`
    - Computes current + previous period stats, generates summary/plan, writes `student_reports`.
    - Inserts a `notification_events` row (`progress_report_ready`).

### Regeneration Behavior
When a student selects a step (or changes it), `set_attempt_step` requeues the `attempt_insight` job. The worker always upserts the insight, so the new attempt-step selection overwrites the previous result.

## Notifications (Draft)
- `notification_events` is an outbox table for push notifications.
- Sender worker claims queued events via `claim_notification_events`, sends APNs/FCM, then marks as `sent` or `error`.
- `push_tokens` stores per-student device tokens. `register_push_token` Edge Function upserts tokens.

## Environment Variables
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `AI_WORKER_SECRET` (required by `process_ai_jobs`)

## Tests
- `deno test --allow-read --allow-env supabase/functions/`
  - Includes `_shared/ai_coach_test.ts` for draft logic.

## Notes
- The draft responses are English and deterministic. Replace the draft builders with real model calls.
- The fallback procedure uses a generic step list that mirrors the current iOS step picker.
- Notification delivery is intentionally deferred to a dedicated sender worker.
