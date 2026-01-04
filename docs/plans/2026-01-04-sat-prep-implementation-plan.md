# SAT Prep MVP Backend Implementation Plan

**Goal:** Stand up the Supabase backend foundation (schema, RLS, core edge functions, and minimal seed data) to unblock iOS + web development.

**Architecture:** Supabase Postgres stores question bank, sessions, attempts, and AI explanations. RLS enforces student/parent access. Edge Functions handle scoring and AI explanation generation with caching.

**Tech Stack:** Supabase (Postgres, RLS, Storage, Edge Functions), Deno for edge function code.

---

### Task 1: Add Supabase project structure and config

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/.gitkeep`

**Step 1: Write minimal config**

```toml
# supabase/config.toml
project_id = "local"
[api]
port = 54321
[db]
port = 54322
```

**Step 2: Verify folder layout**

Run: `ls supabase`
Expected: `config.toml` is present.

**Step 3: Commit**

```bash
git add supabase/config.toml supabase/.gitkeep
git commit -m "chore: add supabase config skeleton"
```

---

### Task 2: Create initial schema and RLS policies

**Files:**
- Create: `supabase/migrations/202601040001_init.sql`

**Step 1: Write the migration**

```sql
-- supabase/migrations/202601040001_init.sql

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('student','parent','admin')),
  display_name text,
  created_at timestamptz default now()
);

create table if not exists public.parent_student_links (
  parent_id uuid references public.profiles(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz default now(),
  primary key (parent_id, student_id)
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  module text not null,
  difficulty int not null,
  question_type text not null check (question_type in ('mcq','numeric')),
  stem text not null,
  answer_key jsonb not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.questions(id) on delete cascade,
  label text not null,
  content text not null
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null
);

create table if not exists public.question_tags (
  question_id uuid references public.questions(id) on delete cascade,
  tag_id uuid references public.tags(id) on delete cascade,
  primary key (question_id, tag_id)
);

create table if not exists public.question_assets (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.questions(id) on delete cascade,
  asset_url text not null,
  asset_type text not null,
  created_at timestamptz default now()
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.profiles(id) on delete cascade,
  mode text not null default 'practice',
  total_questions int not null default 0,
  correct_count int not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.sessions(id) on delete cascade,
  question_id uuid references public.questions(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  answer jsonb,
  is_correct boolean,
  duration_ms int,
  skipped boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.ai_explanations (
  question_id uuid primary key references public.questions(id) on delete cascade,
  content text not null,
  model text not null,
  prompt_version text not null,
  cost_usd numeric,
  created_at timestamptz default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.tags enable row level security;
alter table public.question_tags enable row level security;
alter table public.question_assets enable row level security;
alter table public.sessions enable row level security;
alter table public.attempts enable row level security;
alter table public.ai_explanations enable row level security;

-- Profiles: users can read/update their own profile
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Questions: readable by any authenticated user
create policy "questions_read" on public.questions
  for select using (auth.role() = 'authenticated');
create policy "question_options_read" on public.question_options
  for select using (auth.role() = 'authenticated');
create policy "tags_read" on public.tags
  for select using (auth.role() = 'authenticated');
create policy "question_tags_read" on public.question_tags
  for select using (auth.role() = 'authenticated');
create policy "question_assets_read" on public.question_assets
  for select using (auth.role() = 'authenticated');

-- Sessions/Attempts: students can write/read their own
create policy "sessions_student_rw" on public.sessions
  for all using (auth.uid() = student_id);
create policy "attempts_student_rw" on public.attempts
  for all using (auth.uid() = student_id);

-- Parent links: parents can read their own links
create policy "parent_links_read" on public.parent_student_links
  for select using (auth.uid() = parent_id);

-- AI explanations: read by authenticated users, write by service role only
create policy "ai_explanations_read" on public.ai_explanations
  for select using (auth.role() = 'authenticated');
```

**Step 2: Validate SQL syntax (manual)**

Run: `supabase db reset`
Expected: migration runs without SQL errors.

**Step 3: Commit**

```bash
git add supabase/migrations/202601040001_init.sql
git commit -m "feat: add initial schema and RLS"
```

---

### Task 3: Add pure scoring logic + tests

**Files:**
- Create: `supabase/functions/_shared/scoring.ts`
- Create: `supabase/functions/_shared/scoring_test.ts`

**Step 1: Write failing tests**

```ts
// supabase/functions/_shared/scoring_test.ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { scoreAttempt } from "./scoring.ts";

Deno.test("scoreAttempt - mcq correct", () => {
  const result = scoreAttempt({ questionType: "mcq", answerKey: { correct: "B" } }, { answer: "B" });
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric correct", () => {
  const result = scoreAttempt({ questionType: "numeric", answerKey: { correct: 12 } }, { answer: 12 });
  assertEquals(result.isCorrect, true);
});
```

**Step 2: Run test to verify it fails**

Run: `deno test supabase/functions/_shared/scoring_test.ts`
Expected: FAIL (scoreAttempt not defined).

**Step 3: Write minimal implementation**

```ts
// supabase/functions/_shared/scoring.ts
export function scoreAttempt(
  question: { questionType: "mcq" | "numeric"; answerKey: { correct: string | number } },
  attempt: { answer: string | number | null }
) {
  const isCorrect = attempt.answer === question.answerKey.correct;
  return { isCorrect };
}
```

**Step 4: Run test to verify it passes**

Run: `deno test supabase/functions/_shared/scoring_test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add supabase/functions/_shared/scoring.ts supabase/functions/_shared/scoring_test.ts
git commit -m "feat: add scoring helper"
```

---

### Task 4: Implement submit_attempt edge function (validation + scoring)

**Files:**
- Create: `supabase/functions/submit_attempt/index.ts`

**Step 1: Write minimal handler (manual validation)**

```ts
// supabase/functions/submit_attempt/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { scoreAttempt } from "../_shared/scoring.ts";

serve(async (req) => {
  const body = await req.json();
  if (!body.question || !body.attempt) {
    return new Response(JSON.stringify({ error: "invalid_payload" }), { status: 400 });
  }
  const result = scoreAttempt(body.question, body.attempt);
  return new Response(JSON.stringify({ ...result }), { status: 200 });
});
```

**Step 2: Quick local smoke test**

Run: `supabase functions serve submit_attempt`
Expected: function starts locally without errors.

**Step 3: Commit**

```bash
git add supabase/functions/submit_attempt/index.ts
git commit -m "feat: add submit_attempt function skeleton"
```

---

### Task 5: Implement generate_explanation edge function (cache + LLM stub)

**Files:**
- Create: `supabase/functions/generate_explanation/index.ts`

**Step 1: Add caching-first handler (stub LLM)**

```ts
// supabase/functions/generate_explanation/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const body = await req.json();
  if (!body.question_id) {
    return new Response(JSON.stringify({ error: "invalid_payload" }), { status: 400 });
  }
  // Placeholder until DB access wired
  const explanation = "[stub] explanation";
  return new Response(JSON.stringify({ content: explanation }), { status: 200 });
});
```

**Step 2: Local smoke test**

Run: `supabase functions serve generate_explanation`
Expected: function starts locally without errors.

**Step 3: Commit**

```bash
git add supabase/functions/generate_explanation/index.ts
git commit -m "feat: add generate_explanation function skeleton"
```

---

### Task 6: Add minimal seed data

**Files:**
- Create: `supabase/seed.sql`

**Step 1: Add sample tags and questions**

```sql
-- supabase/seed.sql
insert into public.tags (id, name, category) values
  (gen_random_uuid(), 'Linear equations', 'math'),
  (gen_random_uuid(), 'Main idea', 'reading');

insert into public.questions (subject, module, difficulty, question_type, stem, answer_key)
values
  ('math', 'algebra', 2, 'mcq', 'If x + 2 = 5, what is x?', '{"correct": "B"}');

insert into public.question_options (question_id, label, content)
select q.id, 'A', '1' from public.questions q limit 1;
```

**Step 2: Load seed locally**

Run: `supabase db reset --seed`
Expected: seed runs without errors.

**Step 3: Commit**

```bash
git add supabase/seed.sql
git commit -m "chore: add minimal seed data"
```

---

## Next Plan (separate)
After backend foundation is merged, create a second plan for:
- iOS student app UI + Supabase integration
- Parent web dashboard (Next.js) + Supabase integration

---

Plan complete and saved to `docs/plans/2026-01-04-sat-prep-implementation-plan.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. Parallel Session (separate) - Open new session with executing-plans, batch execution with checkpoints

Which approach?
