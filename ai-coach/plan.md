# AI Coach Plan

## Goals (MVP)
- Process wrong attempts (`attempts.is_correct=false`) asynchronously.
- For each wrong attempt, produce:
  - `procedure_id` + `steps` (create/merge guardrails)
  - `error_step_index` + `error_mode_enum`
  - short explanation + 1–2 follow-up questions
  - similar mistakes evidence (procedure + step)
- Persist results to DB (`attempt_insights`) and update `student_snapshot`.
- Provide a Coach Service (Node/TS worker) that claims jobs from DB and runs the agent.

## Milestones
1. DB migrations + schema doc update
2. Coach Service skeleton (config, DB client, job loop)
3. Attempt insight agent + tool implementations
4. (Later) iOS UI: step selection + coach thread UI

## Tracking
- [ ] Milestone 1
- [ ] Milestone 2
- [ ] Milestone 3
- [ ] Milestone 4
