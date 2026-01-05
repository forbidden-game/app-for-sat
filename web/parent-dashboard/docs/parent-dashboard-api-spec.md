# Parent Dashboard API/Data Spec (MVP)

Date: 2026-01-05

## Purpose
Define the minimal data contract and aggregation expectations for the parent dashboard MVP. This spec complements the product design doc and is intended for backend implementation alignment.

## Scope
- Student overview metrics (7d window)
- Last 5 sessions trend
- Topic/tag strengths & weaknesses
- Parent access boundaries

## Assumptions (Current MVP)
- Comparison cohort: all users.
- Session is the unit of assessment for trend.
- Study time allows idle time (no per-attempt cap).

## Data Contract (Frontend Expected Shape)

```json
{
  "student": {
    "id": "uuid",
    "name": "string",
    "grade": "string"
  },
  "overview": {
    "window_days": 7,
    "practice_minutes": 123.4,
    "accuracy": 0.86,
    "error_rate": 0.14,
    "rank_percentile": 0.78,
    "attempts": 42
  },
  "trend": [
    {
      "session_id": "uuid",
      "created_at": "2026-01-05T10:00:00Z",
      "accuracy": 0.9,
      "rank_percentile": 0.8,
      "attempts": 20,
      "duration_minutes": 35.0
    }
  ],
  "topics": [
    {
      "tag_id": "uuid",
      "tag_name": "algebra",
      "accuracy": 0.72,
      "attempts": 18
    }
  ]
}
```

## Metrics Definitions

### Overview (7d)
- practice_minutes = sum(attempt.duration_ms) / 60000
- accuracy = correct / (correct + incorrect)
- error_rate = incorrect / (correct + incorrect)
- attempts = correct + incorrect
- rank_percentile = percentile of accuracy_7d among eligible students
  - eligible: attempts_7d >= 20

### Trend (Last 5 Sessions)
- source: last 5 sessions by created_at desc
- accuracy: per-session correct / attempted
- rank_percentile: derived from current-window ranking (MVP approximation)
- attempts: per-session correct + incorrect
- duration_minutes: sum(attempt.duration_ms)/60000

### Topics (7d)
- accuracy: correct / (correct + incorrect)
- attempts: correct + incorrect
- filter: attempts >= 10
- dimension: tags from question_tags + tags

## Access & Security (RLS Expectations)
- Parent can read only linked students.
- Student data must be filtered by parent_student_links.
- Aggregates should be read-only for clients.

## Suggested Data Sources
- Base tables: sessions, attempts, question_tags, tags, parent_student_links, profiles
- Aggregation options:
  - Views or materialized views per student
  - RPC functions for composite payload

## Implementation Notes (Backend)
- Preferred: a single RPC that returns the full payload for one student.
- Alternative: three views + client-side composition.
- Ensure indexes on attempts(student_id, created_at), sessions(student_id, created_at).
- Consider caching rank_percentile if cohort grows large.

## Edge Cases
- No data: return empty trend/topics and overview attempts=0
- Low sample: if attempts < 20, rank_percentile = null
- If no tags meet threshold, return empty topics list
