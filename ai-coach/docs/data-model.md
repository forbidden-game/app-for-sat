# Data Model（MVP）
日期：2026-01-14

北极星：这些结构用于支撑“每个学生一个 AI 老师”的长期记忆与错题追问。

本页描述在现有 Supabase schema（`attempts/questions/tags/sessions` 等）基础上，建议新增的最小数据结构。

> 命名为建议，实际迁移可根据你们现有风格调整。

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
- 可选：`embedding vector`（用于去重/近邻检索）

## 2) `public.attempt_insights`
每次作答的结构化诊断结果（用于检索、统计、长期追踪）。

字段建议：
- `attempt_id` uuid PK FK -> `attempts.id`
- `student_id` uuid FK -> `profiles.id`
- `question_id` uuid FK -> `questions.id`
- `procedure_id` uuid FK -> `procedures.id`
- `procedure_steps_version` int（记录当次使用的 version）
- `error_step_index` int（0-based 或 1-based 需统一）
- `student_selected_step_index` int nullable
- `student_selected_step_is_unknown` boolean default false
- `error_mode_enum` text（见 `error-modes.md`，必须含 `unknown`）
- `error_mode_detail` text nullable（允许 AI 记录更细但不稳定的描述）
- `evidence` jsonb（证据链：引用题干条件、选项陷阱、学生选择 vs 正确选择差异、用时等）
- `explanation_short` text（短讲解，MVP 用）
- `followups` jsonb（1–2 个追问问题，含期望回答形式）
- `confidence` numeric（0~1）
- `model` text
- `prompt_version` text
- `cost_usd` numeric
- `created_at` timestamptz default now()

索引建议：
- `(student_id, procedure_id, error_step_index, created_at)`
- `(student_id, created_at)`

## 3) `public.student_snapshot`
学生长期状态快照（用于对话注入；避免每次扫描全历史）。

字段建议：
- `student_id` uuid PK FK -> `profiles.id`
- `subject_scope` text（MVP 可固定 `all` 或 `sat_math`）
- `weak_procedures_top` jsonb（topN：procedure_id + 指标）
- `weak_steps_top` jsonb（topN：procedure_id + step + 指标）
- `common_error_modes_top` jsonb（topN：error_mode_enum + 指标）
- `recent_trend` jsonb（7/30 天：正确率、用时、重复错次数等）
- `notes` text（极短摘要，可选）
- `updated_at` timestamptz default now()

更新策略：
- 每次写入 `attempt_insights` 后触发更新（可以先用应用层更新；后续可做 DB function）。

## 4) `public.coach_thread_messages`
学生“全科老师总线程”的对话记录（跨题）。

字段建议：
- `id` uuid PK default `gen_random_uuid()`
- `student_id` uuid FK -> `profiles.id`
- `role` text enum: `user|assistant|tool`（或按你们现有消息体系）
- `content` jsonb（支持富结构：文本、引用、关联 attempt_id 等）
- `linked_attempt_id` uuid nullable
- `created_at` timestamptz default now()

可选：`public.coach_thread_summaries`
- 用于定期压缩旧对话，减少上下文。

## 5) （可选）`public.ai_jobs`
异步任务表：错题分析、对话总结、procedure 合并建议等。

字段建议：
- `id` uuid PK
- `kind` text（`attempt_insight`/`thread_summary`/`procedure_merge`）
- `payload` jsonb
- `status` text（`queued|running|done|error`）
- `error` text
- `created_at`, `updated_at`

## 6) `public.ai_provider_keys`
Provider key（服务端读取，MVP 仅 OpenRouter）。

字段建议：
- `id` uuid PK
- `provider` text（`openrouter`）
- `api_key` text
- `created_by` / `updated_by` uuid
- `created_at` / `updated_at` timestamptz

## 7) `public.ai_agent_logs`
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
- `status` text（`done` | `error`）
- `error` text
- `created_at` timestamptz
