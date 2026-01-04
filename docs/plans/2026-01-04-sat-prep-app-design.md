# SAT Prep App Design (iOS Student + Web Parent)

Date: 2026-01-04

## Summary
Build an iOS student app focused on an infinite vertical question feed and a separate parent web dashboard. Use Supabase (Auth, Postgres, RLS, Storage, Edge Functions) as the backend. Support multiple-choice and numeric-input questions. Track every attempt and session for progress analytics. Generate AI explanations on demand via server-side functions with caching and cost control.

## Goals
- Fast, engaging student practice with swipe-based question flow.
- Clear parent visibility into learning progress, strengths, and weaknesses.
- Reliable learning history with metrics at session, topic, and trend levels.
- Scalable data model that supports more question types and modes later.

## Non-goals (for now)
- Full SAT timed simulation and adaptive scoring.
- Multi-language UI.
- Teacher or classroom features.
- Marketplace or subscription billing.

## Users and Roles
- Student: practices, submits answers, views explanations, sees personal stats.
- Parent: views linked student progress and details.
- Admin (internal): manages question bank and monitoring.

## Architecture and Tech Stack
- Student app: iOS native (SwiftUI or UIKit).
- Parent app: Web (Next.js, responsive UI).
- Backend: Supabase
  - Auth for accounts and role claims.
  - Postgres for core data and analytics.
  - RLS policies for strict data access.
  - Storage for images/media.
  - Edge Functions for scoring, AI explanation, and aggregation jobs.
- AI: server-side LLM calls from Edge Functions.

## Data Model (Core Tables)
- users
  - id, role (student/parent/admin), profile fields.
- parent_student_links
  - parent_id, student_id, status.
- questions
  - id, subject, module, difficulty, question_type (mcq/numeric), stem, answer_key (json), metadata.
- question_options
  - question_id, label, content (optional for numeric).
- question_tags
  - question_id, tag_id.
- tags
  - id, name, category.
- question_assets
  - question_id, asset_url, type.
- sessions
  - id, student_id, mode (practice), created_at, stats.
- attempts
  - id, session_id, question_id, student_id, answer, is_correct, duration_ms, skipped, created_at.
- ai_explanations
  - question_id, content, model, prompt_version, cost, created_at.
- aggregates (materialized or precomputed)
  - per_student_topic_stats, per_student_weekly_stats, etc.

## Permissions (RLS)
- Students can read questions and write only their own sessions/attempts.
- Parents can read only linked students' aggregate views and attempt summaries.
- AI explanations are written only by server functions.
- Admin has elevated access for question management.

## Core Flows
1) Generate practice session:
   - Client requests a session with filters (subject, module, tags, difficulty).
   - Backend selects question set and returns question list without answer keys.

2) Answer submission:
   - Client sends attempt data per question.
   - Edge Function validates, scores, updates session stats, and updates aggregates.

3) AI explanation:
   - Client requests explanation for a question.
   - Edge Function checks cache; if missing, calls LLM, stores result, returns content.

4) Parent insights:
   - Parent dashboard loads precomputed aggregates and supports drill-down into session details and wrong questions.

## Student App UX (Key Screens)
- Question feed (vertical swipe): stem, options/input, progress indicator.
- Answer feedback: correct/incorrect; link to explanation.
- Session summary: score, accuracy, time, weak topics.
- Filters: subject/module/tag/difficulty.
- Bookmarks and unsure marks (optional).

## Parent Web UX (Key Screens)
- Dashboard: weekly/monthly trends, total practice time, accuracy.
- Topic breakdown: strengths and weaknesses by tag/module.
- Session detail: wrong questions list with explanations.
- Student history timeline (summary events).

## AI Explanation Control
- On-demand generation only.
- Caching by question_id + prompt_version.
- Error fallback (no explanation available).
- Usage limits per student/day and cost monitoring.

## Error Handling and Offline
- Client stores attempts locally on failure and retries.
- Edge Function returns structured errors.
- UI shows safe fallbacks (retry, cached data).

## Observability
- AI success rate, latency, cost per explanation.
- Attempt ingestion success rate.
- Session completion rate.

## Testing
- iOS: UI tests for login, question flow, submission, summary.
- Backend: unit tests for scoring, AI caching, and RLS policies.
- Data checks: attempts-to-session consistency.

## Delivery Phases (no time estimates)
1) MVP: question feed, attempts, session summary, basic parent dashboard, minimal question bank.
2) Enhanced: AI explanations, weak-topic recommendations, deeper parent drill-down.
3) Exam simulation: timed modules, adaptive scoring, score prediction.

## Risks and Mitigations
- AI cost spikes: enforce quotas and cache aggressively.
- Data privacy: strict RLS, server-only writes for sensitive tables.
- Content quality: tag system + admin review pipeline.

## Open Questions
- Final choice of iOS UI framework (SwiftUI vs UIKit).
- Initial size and sourcing of the question bank.
- Specific analytics to highlight for parents in MVP.
