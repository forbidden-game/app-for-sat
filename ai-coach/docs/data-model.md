# Data Model（MVP + v2）

日期：2026-01-22

北极星：这些结构用于支撑“每个学生一个 AI 老师”的长期记忆与错题追问。

本页描述在现有 Supabase schema（`attempts/questions/tags/sessions` 等）基础上，新增的核心数据结构与实际工作字段。

## 1) `public.procedures`

AI 自增长的“解题套路库”（procedure taxonomy）。

字段建议：

- `id` uuid PK default `gen_random_uuid()`
- `subject` text（MVP: `sat_math`）
- `name` text（短名，如 "Linear equation isolation"）
- `description` text（1–2 句）
- `steps` jsonb（数组，3–7 条短句）
- `steps_version` int default 1
- `aliases` text[] default `{}`（同义名/旧名，支持合并后保留）
- `status` text enum: `active|merged|deprecated` default `active`
- `merged_into` uuid nullable（若 merged 指向目标 procedure）
- `created_by` text（`ai`/`admin`）
- `created_at` timestamptz default now()
- `updated_at` timestamptz default now()

索引建议：

- `(subject, status)`
- `name`（可加 trigram）

## 2) `public.attempt_insights`

每次作答的结构化诊断结果（用于检索、统计、长期追踪）。

字段建议：

- `attempt_id` uuid PK FK -> `attempts.id`
- `student_id` uuid FK -> `profiles.id`
- `question_id` uuid FK -> `questions.id`
- `procedure_id` uuid FK -> `procedures.id`
- `procedure_steps_version` int（记录当次使用的 version）
- `error_step_index` int
- `student_selected_step_index` int nullable
- `student_selected_step_is_unknown` boolean default false
- `error_mode_enum` text（见 `error-modes.md`，必须含 `unknown`）
- `error_mode_detail` text nullable
- `evidence` jsonb
- `explanation_short` text
- `followups` jsonb
- `confidence` numeric (0~1)
- `model` text
- `prompt_version` text
- `cost_usd` numeric
- `created_at` timestamptz default now()

## 3) `public.student_snapshots`

学生长期状态快照（用于对话注入）。

字段建议：

- `student_id` uuid PK FK -> `profiles.id`
- `subject_scope` text
- `weak_procedures_top` jsonb
- `weak_steps_top` jsonb
- `common_error_modes_top` jsonb
- `recent_trend` jsonb
- `notes` text
- `updated_at` timestamptz default now()

## 4) `public.coach_thread_messages`

学生“全科老师总线程”的对话记录（跨题）。

字段建议：

- `id` uuid PK default `gen_random_uuid()`
- `student_id` uuid FK -> `profiles.id`
- `role` text enum: `user|assistant|tool`
- `content` jsonb（可包含 `text` 与状态）
- `linked_attempt_id` uuid nullable
- `reply_to_message_id` uuid nullable
- `created_at` timestamptz default now()

## 5) `public.student_reports`

阶段报告（周报/月报）。

字段建议：

- `id` uuid PK default `gen_random_uuid()`
- `student_id` uuid not null
- `period_kind` text not null (weekly|monthly)
- `period_key` text not null
- `period_start` timestamptz not null
- `period_end` timestamptz not null
- `metrics` jsonb not null
- `delta` jsonb not null
- `summary` text not null
- `plan` jsonb not null
- `model` text
- `prompt_version` text
- `cost_usd` numeric
- `created_at` timestamptz default now()

约束：unique(student_id, period_key)

## 6) `public.ai_jobs`

异步任务表（MVP + v2）

字段：

- `id` uuid PK
- `kind` text
- `status` text (queued|running|done|error)
- `attempt_id` uuid nullable
- `student_id` uuid nullable
- `payload` jsonb not null
- `run_after` timestamptz not null
- `locked_at` timestamptz nullable
- `locked_by` text nullable
- `dedupe_key` text nullable
- `attempt_count` int default 0
- `error` text nullable
- `last_error` text nullable
- `last_error_at` timestamptz nullable
- `last_error_code` text nullable
- `completed_at` timestamptz nullable
- `created_at`/`updated_at`

索引：

- `(status, run_after)`
- `(status, updated_at)`
- unique(kind, dedupe_key) where dedupe_key is not null

## 7) `public.notification_events`

通知发送队列。

字段：

- `id` uuid PK
- `student_id` uuid not null
- `event_type` text
- `payload` jsonb
- `status` text (queued|sending|sent|error)
- `error` text nullable
- `locked_at` timestamptz nullable
- `locked_by` text nullable
- `created_at`/`updated_at`

## 8) `public.ai_provider_keys`

Provider key（服务端读取）。

字段建议：

- `id` uuid PK
- `provider` text（`minimax` | `openai` | `openrouter`）
- `api_key` text
- `created_by` / `updated_by` uuid
- `created_at` / `updated_at` timestamptz

## 9) `public.ai_agent_logs`

AI Coach agent 执行日志（prompt + tool 轨迹，用于 debug）。

字段建议：

- `id` uuid PK
- `job_id` uuid nullable
- `kind` text
- `student_id` uuid nullable
- `attempt_id` uuid nullable
- `model_provider` text
- `model_id` text
- `prompt_version` text
- `system_prompt` text
- `prompts` jsonb
- `events` jsonb
- `status` text（done|error）
- `error` text
- `created_at` timestamptz
