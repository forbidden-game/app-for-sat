# AI Coach Cloud E2E (Smoke)

These tests run against a **Supabase Cloud** project and validate the AI Coach integration points:
- Edge Functions auth + writes (`submit_attempt`, `set_attempt_step`, `coach_chat`)
  - Note: these tests expect the **new** `submit_attempt` response shape including `attemptId`.
- DB triggers enqueue `ai_jobs` rows

They are intentionally **smoke-level** (no LLM assertions by default) to avoid cost/flakiness.

## Prerequisites
- A **staging** Supabase project (recommended).
- Local env vars exported (do **not** commit secrets):

```bash
set -a
source web/admin-dashboard/.env.local
set +a
```

Required variables:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Run

```bash
deno test --allow-env --allow-net ai-coach/tests/cloud-e2e/
```

## What the tests do
- Create a temporary student user.
- Create a temporary question + question bank.
- Start a practice session and submit a wrong attempt (verifies `ai_jobs(kind='attempt_insight')`).
- Send a coach chat message (verifies `ai_jobs(kind='coach_reply')`).
- Cleanup all created data.

## Notes
- These tests **write** to the target project (but cleanup after themselves).
- If a worker is running against the same project, jobs may move from `queued` → `running`/`done` quickly; tests accept that.
