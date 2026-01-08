# AGENTS.md — SAT Prep Student App

## Project Structure

```
ios/
├── StudentApp/           # SwiftUI iOS application (Xcode project)
│   └── StudentApp/
│       ├── Views/        # SwiftUI views
│       └── ViewModels/   # App-level view models
└── StudentCore/          # Swift Package (business logic, models, services)
    └── Sources/StudentCore/

web/
├── parent-dashboard/     # Next.js 16 — Parent-facing dashboard
│   └── src/
│       ├── app/          # App Router pages
│       ├── components/   # React components
│       └── lib/          # Utilities, Supabase client
└── admin-dashboard/      # Next.js 16 — Admin console
    └── src/              # Same structure as parent-dashboard

supabase/
├── migrations/           # SQL migrations (versioned: YYYYMMDDHHMM_name.sql)
├── functions/            # Deno Edge Functions
│   ├── submit_attempt/   # Scoring endpoint
│   └── _shared/          # Shared modules (scoring.ts)
├── seed.sql              # Dev seed data (auto-generated)
└── docs/schema.md        # Schema documentation (keep in sync!)
```

---

## Build & Test Commands

### iOS — StudentCore (Swift Package)
```bash
swift build --package-path ios/StudentCore
swift test --package-path ios/StudentCore
swift test --package-path ios/StudentCore --filter QuestionFeedViewModelTests/testAdvanceMovesIndex
swift package clean --package-path ios/StudentCore
```

### iOS — StudentApp (Xcode)
```bash
xcodebuild -project ios/StudentApp/StudentApp.xcodeproj \
  -scheme StudentApp -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Prefer xcodebuild MCP tools for interactive development.

### Web — Next.js Apps
```bash
# Parent Dashboard
cd web/parent-dashboard && npm install && npm run dev   # Dev server :3000
npm run build                                            # Production build
npm run lint                                             # ESLint
npm run test                                             # Vitest (all tests)
npx vitest run src/lib/format.test.ts                   # Single test file

# Admin Dashboard (same commands)
cd web/admin-dashboard && npm install && npm run dev    # Dev server :3000
```

### Supabase
```bash
supabase start                          # Start local stack (db:54322, api:54321)
supabase stop                           # Stop local stack
supabase db reset                       # Reset + re-run migrations + seed
supabase migration new <name>           # Create new migration
supabase functions serve submit_attempt # Run Edge Function locally

# Test Edge Function shared module
deno test --allow-read supabase/functions/_shared/scoring_test.ts
```

---

## Automation & Verification

- Prefer executing commands, checks, and validations yourself instead of asking the user to do them.
- When remote resources are involved (e.g., managed databases, hosted Supabase projects), ask for the minimum required connection details and credentials, then perform the verification directly.
- If additional access is needed (VPN, SSH, allowlist, MFA), request the missing info explicitly and proceed once provided.
- Only ask the user to run commands when access cannot be delegated or tooling is unavailable; otherwise, automate and report results.

---

## Code Style Guidelines

### TypeScript / React (Web)

| Element | Convention | Example |
|---------|------------|---------|
| Components | PascalCase | `DashboardPage`, `AuthGate` |
| Functions, variables | camelCase | `formatPercent`, `isLoading` |
| Types | PascalCase | `ParentDashboard`, `QuestionBank` |
| Constants | camelCase or UPPER_SNAKE | `chartWidth`, `BANK_MODES` |
| Files | kebab-case or match export | `format.ts`, `supabaseClient.ts` |

**Import order**: React/Next → third-party → local (`@/lib/...`)

```tsx
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
```

**Component pattern**: Use `"use client"` directive for client components. Extract types at top of file.

**Error handling**: Always handle Supabase errors explicitly:
```ts
const { data, error } = await supabase.from("table").select();
if (error) throw new Error(error.message);
```

### Swift (iOS)

| Element | Convention | Example |
|---------|------------|---------|
| Types | UpperCamelCase | `QuestionFeedViewModel` |
| Properties, methods | lowerCamelCase | `currentIndex`, `advance()` |
| Enum cases | lowerCamelCase | `case previous` |

**Public API**: Explicit `public` + `public init` for package types.
**ViewModels**: `@Published public private(set)` for controlled state.
**Theming**: Use `AppTheme` tokens for fills, strokes, shadows, and overlays (avoid raw `Color.black`/`Color.white` in views).

### SQL (Supabase Migrations)

- File naming: `YYYYMMDDHHMM_description.sql` (e.g., `202601050001_auth_profiles.sql`)
- Always enable RLS: `alter table public.X enable row level security;`
- Use `gen_random_uuid()` for primary keys
- Document schema changes in `supabase/docs/schema.md` in the same PR

### Deno Edge Functions

```ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
```

- Use explicit URL imports with version pins
- JWT auth required: check `Authorization: Bearer <token>`
- Return JSON with `Content-Type: application/json`

---

## Testing Patterns

### Web (Vitest)
```ts
import { describe, it, expect } from "vitest";
import { formatPercent } from "./format";

describe("formatPercent", () => {
  it("formats ratio as percent", () => {
    expect(formatPercent(0.875)).toBe("87.5%");
  });
});
```

### iOS (XCTest)
```swift
@testable import StudentCore
// Use mock implementations for protocols
public final class MockAPIClient: APIClient { ... }
```

### Deno (Edge Functions)
```ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
Deno.test("scoreAttempt mcq correct", () => { ... });
```

---

## Key Dependencies

| Layer | Stack |
|-------|-------|
| iOS | Swift 6.2, SwiftUI, supabase-swift 2.0+ |
| Web | Next.js 16, React 19, TypeScript 5, Tailwind 4, Vitest |
| Backend | Supabase (Postgres, Auth, Edge Functions), Deno |

---

## Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `StudentCore` | `ios/StudentCore/` | iOS business logic, models, API client |
| `parent-dashboard` | `web/parent-dashboard/` | Parent analytics & monitoring |
| `admin-dashboard` | `web/admin-dashboard/` | Question bank & user management |
| `submit_attempt` | `supabase/functions/` | Server-side scoring Edge Function |
| `schema.md` | `supabase/docs/` | Database schema documentation |

---

## Environment Variables

### Web Apps (`.env.local`)
```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon_key>
```

### Edge Functions (auto-injected by Supabase)
```
SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
```

---

## Git Conventions

- Commit only files you modified
- No force push, no history rewriting unless requested
- Use `gh` CLI for GitHub operations
- Schema changes require `supabase/docs/schema.md` update in same PR

---

## Language & Documentation

- **Code, comments, identifiers, commits**: English only
- **Conversation**: Chinese acceptable (per user preference)
- Comments: Explain "why", not "what"

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: Bash("openskills read <skill-name>")
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>swift-concurrency</name>
<description>Expert guidance on Swift Concurrency best practices, patterns, and implementation. Use when developers mention: (1) Swift Concurrency, async/await, actors, or tasks, (2) "use Swift Concurrency" or "modern concurrency patterns", (3) migrating to Swift 6, (4) data races or thread safety issues, (5) refactoring closures to async/await, (6) @MainActor, Sendable, or actor isolation, (7) concurrent code architecture or performance optimization.</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
