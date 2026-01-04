# SAT Prep Parent Web Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the parent-facing web dashboard MVP (login, dashboard, student detail, session detail).

**Architecture:** Next.js App Router with a lightweight data layer and Supabase client. UI is componentized with a simple auth gate.

**Tech Stack:** Next.js (App Router), React, TypeScript, Tailwind CSS, Supabase JS, Vitest.

---

### Task 1: Scaffold Next.js app

**Files:**
- Create: `web/parent-dashboard/` (Next.js app)

**Step 1: Scaffold**

Run:
```bash
npx create-next-app@latest web/parent-dashboard --typescript --eslint --app --src-dir --tailwind --use-npm
```
Expected: `Success! Created web/parent-dashboard`.

**Step 2: Verify dev server**

Run:
```bash
cd web/parent-dashboard && npm run dev
```
Expected: app runs at `http://localhost:3000`.

**Step 3: Commit**

```bash
git add web/parent-dashboard
git commit -m "chore: scaffold parent dashboard"
```

---

### Task 2: Add Vitest test setup

**Files:**
- Create: `web/parent-dashboard/vitest.config.ts`
- Modify: `web/parent-dashboard/package.json`

**Step 1: Install Vitest**

Run:
```bash
cd web/parent-dashboard && npm install -D vitest
```
Expected: `added ... packages`.

**Step 2: Add test script and config**

```ts
// web/parent-dashboard/vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
  },
});
```

```json
// package.json (add script)
{
  "scripts": {
    "test": "vitest"
  }
}
```

**Step 3: Commit**

```bash
git add web/parent-dashboard/vitest.config.ts web/parent-dashboard/package.json
git commit -m "chore: add vitest"
```

---

### Task 3: Add a small formatting helper with tests

**Files:**
- Create: `web/parent-dashboard/src/lib/format.ts`
- Create: `web/parent-dashboard/src/lib/format.test.ts`

**Step 1: Write failing test**

```ts
// web/parent-dashboard/src/lib/format.test.ts
import { describe, it, expect } from "vitest";
import { formatPercent } from "./format";

describe("formatPercent", () => {
  it("formats ratio as percent", () => {
    expect(formatPercent(0.875)).toBe("87.5%")
  });
});
```

**Step 2: Run test to verify it fails**

Run:
```bash
cd web/parent-dashboard && npm test
```
Expected: FAIL (formatPercent not found).

**Step 3: Implement helper**

```ts
// web/parent-dashboard/src/lib/format.ts
export function formatPercent(value: number) {
  return `${(value * 100).toFixed(1)}%`;
}
```

**Step 4: Run tests to verify pass**

Run: `cd web/parent-dashboard && npm test`
Expected: PASS

**Step 5: Commit**

```bash
git add web/parent-dashboard/src/lib/format.ts web/parent-dashboard/src/lib/format.test.ts
git commit -m "feat: add formatPercent helper"
```

---

### Task 4: Add Supabase client config

**Files:**
- Create: `web/parent-dashboard/src/lib/supabaseClient.ts`
- Create: `web/parent-dashboard/.env.local.example`

**Step 1: Install Supabase client**

Run:
```bash
cd web/parent-dashboard && npm install @supabase/supabase-js
```
Expected: `added ... packages`.

**Step 2: Add env template**

```env
# web/parent-dashboard/.env.local.example
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

**Step 3: Add client**

```ts
// web/parent-dashboard/src/lib/supabaseClient.ts
import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(url, key);
```

**Step 4: Commit**

```bash
git add web/parent-dashboard/src/lib/supabaseClient.ts web/parent-dashboard/.env.local.example
git commit -m "feat: add supabase client"
```

---

### Task 5: Add AuthGate component

**Files:**
- Create: `web/parent-dashboard/src/components/AuthGate.tsx`

**Step 1: Implement AuthGate**

```tsx
// web/parent-dashboard/src/components/AuthGate.tsx
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "../lib/supabaseClient";

export function AuthGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) router.push("/login");
      else setReady(true);
    });
  }, [router]);

  if (!ready) return null;
  return <>{children}</>;
}
```

**Step 2: Manual smoke test**

Run app, navigate to a protected page and verify redirect to /login when not logged in.

**Step 3: Commit**

```bash
git add web/parent-dashboard/src/components/AuthGate.tsx
git commit -m "feat: add auth gate"
```

---

### Task 6: Add login page

**Files:**
- Create: `web/parent-dashboard/src/app/login/page.tsx`

**Step 1: Implement login page**

```tsx
"use client";

import { useState } from "react";
import { supabase } from "../../lib/supabaseClient";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    await supabase.auth.signInWithOtp({ email });
    setSent(true);
  }

  return (
    <main className="p-6 max-w-sm mx-auto">
      <h1 className="text-xl font-semibold">Parent Login</h1>
      {sent ? (
        <p className="mt-4">Check your email for the login link.</p>
      ) : (
        <form onSubmit={onSubmit} className="mt-4 space-y-3">
          <input className="border p-2 w-full" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
          <button className="bg-black text-white px-4 py-2" type="submit">Send Link</button>
        </form>
      )}
    </main>
  );
}
```

**Step 2: Manual smoke test**

Run app, verify email input and submit button render.

**Step 3: Commit**

```bash
git add web/parent-dashboard/src/app/login/page.tsx
git commit -m "feat: add login page"
```

---

### Task 7: Add dashboard page (stub data)

**Files:**
- Create: `web/parent-dashboard/src/app/(app)/layout.tsx`
- Create: `web/parent-dashboard/src/app/(app)/dashboard/page.tsx`

**Step 1: Add layout with AuthGate**

```tsx
import { AuthGate } from "../../components/AuthGate";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return <AuthGate>{children}</AuthGate>;
}
```

**Step 2: Add dashboard page**

```tsx
import { formatPercent } from "../../../lib/format";

export default function DashboardPage() {
  const stats = { weeklyAccuracy: 0.82, totalQuestions: 120, totalTimeMin: 340 };
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <div className="mt-4 space-y-2">
        <div>Accuracy: {formatPercent(stats.weeklyAccuracy)}</div>
        <div>Total Questions: {stats.totalQuestions}</div>
        <div>Total Time (min): {stats.totalTimeMin}</div>
      </div>
    </main>
  );
}
```

**Step 3: Manual smoke test**

Navigate to `/dashboard`, verify stats render.

**Step 4: Commit**

```bash
git add web/parent-dashboard/src/app/(app)/layout.tsx web/parent-dashboard/src/app/(app)/dashboard/page.tsx
git commit -m "feat: add dashboard page"
```

---

### Task 8: Add student detail page (stub)

**Files:**
- Create: `web/parent-dashboard/src/app/(app)/students/[id]/page.tsx`

**Step 1: Implement page**

```tsx
export default function StudentPage({ params }: { params: { id: string } }) {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Student {params.id}</h1>
      <p className="mt-2">Session history will appear here.</p>
    </main>
  );
}
```

**Step 2: Manual smoke test**

Navigate to `/students/123`, verify the page renders.

**Step 3: Commit**

```bash
git add web/parent-dashboard/src/app/(app)/students/[id]/page.tsx
git commit -m "feat: add student detail page"
```

---

### Task 9: Add session detail page (stub)

**Files:**
- Create: `web/parent-dashboard/src/app/(app)/sessions/[id]/page.tsx`

**Step 1: Implement page**

```tsx
export default function SessionPage({ params }: { params: { id: string } }) {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Session {params.id}</h1>
      <p className="mt-2">Wrong questions list will appear here.</p>
    </main>
  );
}
```

**Step 2: Manual smoke test**

Navigate to `/sessions/abc`, verify the page renders.

**Step 3: Commit**

```bash
git add web/parent-dashboard/src/app/(app)/sessions/[id]/page.tsx
git commit -m "feat: add session detail page"
```

---

## Notes
- Real data wiring to Supabase will follow backend completion.
- Next plan should add data fetching, filtering, and drill-down UI.

---

Plan complete and saved to `docs/plans/2026-01-04-sat-prep-parent-web-plan.md`.
