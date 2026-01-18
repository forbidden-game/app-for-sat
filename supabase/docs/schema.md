# Supabase Schema（MVP）

日期：2026-01-14

北极星：Schema 为“每个学生一个 AI 老师”的长期记忆与错题追问服务。

## 总览
- 表数量：17
- 视图数量：1
- 函数/RPC：12（1 个 auth hook、2 个邀请 RPC、1 个家长端聚合 RPC、2 个练习 session RPC、1 个 admin helper、2 个题库管理 RPC、3 个 AI Coach 统计/队列 RPC）

## 表结构

### `public.profiles`
**用途**：用户资料表（学生/家长/管理员）。由 auth trigger 在注册时自动插入。

**字段**
- `id` uuid，PK，FK -> `auth.users.id`（on delete cascade）
- `role` text，enum：`student|parent|admin`
- `display_name` text
- `created_at` timestamptz，default `now()`

**关系**
- 与 `auth.users` 1:1
- 作为 `parent_student_links` 与 `parent_invite_codes` 的主体引用

---

### `public.admin_audit_logs`
**用途**：管理员在控制台的关键操作审计日志。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `actor_id` uuid，FK -> `profiles.id`（on delete set null）
- `action` text（例如：`user.create`）
- `entity_type` text（例如：`user`）
- `entity_id` uuid（目标实体）
- `payload` jsonb，default `{}`
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `profiles`

---

### `public.parent_student_links`
**用途**：家长与学生的关联表，用于访问控制。

**字段**
- `parent_id` uuid，FK -> `profiles.id`
- `student_id` uuid，FK -> `profiles.id`
- `status` text，default `active`
- `created_at` timestamptz，default `now()`

**约束**
- PK：`(parent_id, student_id)`

**关系**
- 家长与学生的多对多关系

---

### `public.parent_invite_codes`
**用途**：家长绑定学生的邀请码。

**字段**
- `id` uuid，PK
- `parent_id` uuid，FK -> `profiles.id`
- `student_id` uuid，FK -> `profiles.id`（可为空，兑换后写入）
- `code` text，unique
- `status` text，enum：`active|redeemed|expired`
- `created_at` timestamptz，default `now()`
- `redeemed_at` timestamptz
- `expires_at` timestamptz

**关系**
- `parent_id` 指向家长 profile
- `student_id` 在兑换时关联学生

---

### `public.question_types`
**用途**：题目类型定义表，支持自定义类型。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `name` text，unique（类型标识：mcq、numeric 等）
- `display_name` text（显示名称）
- `answer_schema` jsonb，default `{}`（答案格式配置）
- `scoring_type` text，enum：`exact|partial|manual`
- `is_active` boolean，default `true`
- `sort_order` int，default `0`
- `created_at` timestamptz，default `now()`

**预置类型**
- `mcq`：单选题
- `numeric`：数值题

---

### `public.questions`
**用途**：题库主表（题干、答案、元数据）。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `subject` text
- `module` text
- `difficulty` int
- `question_type` text，FK -> `question_types.name`
- `stem` text
- `answer_key` jsonb（格式：`{"correct": "B"}` 或 `{"correct": 42}`）
- `metadata` jsonb，default `{}`
- `created_at` timestamptz，default `now()`

**关系**
- 1:N -> `question_options`
- N:M -> `tags`（通过 `question_tags`）
- 1:N -> `question_assets`
- N:1 -> `question_types`

**备注**
- 学生端不直接读取 `questions`，由 `start_practice_session` 返回不含答案的题目 payload。

---

### `public.question_options`
**用途**：选择题选项。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `question_id` uuid，FK -> `questions.id`
- `label` text
- `content` text

**关系**
- N:1 -> `questions`

---

### `public.tags`
**用途**：题目标签（知识点/题型/维度）。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `name` text，unique
- `category` text

**关系**
- N:M -> `questions`（通过 `question_tags`）

---

### `public.question_tags`
**用途**：题目与标签的关联表。

**字段**
- `question_id` uuid，FK -> `questions.id`
- `tag_id` uuid，FK -> `tags.id`

**约束**
- PK：`(question_id, tag_id)`

**关系**
- 连接 `questions` 与 `tags`

---

### `public.question_assets`
**用途**：题目附件（图片/图表等）。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `question_id` uuid，FK -> `questions.id`
- `asset_url` text（公开访问 URL）
- `asset_type` text（MIME 类型）
- `storage_path` text（Supabase Storage 路径）
- `status` text，enum：`pending|active|deleted`，default `active`
- `created_by` uuid，FK -> `auth.users.id`
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `questions`

---

### `public.question_banks`
**用途**：题库配置与入口（题库索引页展示 + 选题策略配置）。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `slug` text，唯一标识（客户端使用）
- `title` text
- `subtitle` text
- `icon` text
- `mode` text，enum：`fixed|daily_mix`
- `question_limit` int
- `rule_json` jsonb（题库规则/过滤条件）
- `is_active` boolean
- `sort_order` int
- `created_at` timestamptz，default `now()`

**关系**
- 1:N -> `question_bank_questions`
- 1:N -> `sessions`

---

### `public.question_bank_questions`
**用途**：题库与题目的固定编排关系（按顺序出题）。

**字段**
- `bank_id` uuid，FK -> `question_banks.id`
- `question_id` uuid，FK -> `questions.id`
- `position` int

**约束**
- PK：`(bank_id, question_id)`
- Unique：`(bank_id, position)`

**关系**
- N:1 -> `question_banks`
- N:1 -> `questions`

---

### `public.sessions`
**用途**：学生练习/测验的 session 记录。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `student_id` uuid，FK -> `profiles.id`
- `mode` text，default `practice`
- `total_questions` int
- `correct_count` int
- `bank_id` uuid，FK -> `question_banks.id`
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `profiles`
- 1:N -> `attempts`
- 1:N -> `session_questions`
- N:1 -> `question_banks`

---

### `public.attempts`
**用途**：单题作答记录。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `client_submission_id` uuid（客户端幂等 ID，可为空）
- `session_id` uuid，FK -> `sessions.id`
- `question_id` uuid，FK -> `questions.id`
- `student_id` uuid，FK -> `profiles.id`
- `answer` jsonb
- `is_correct` boolean
- `duration_ms` int
- `skipped` boolean，default `false`
- `student_selected_step_index` int（可为空，AI Coach：学生选择卡点步骤）
- `student_selected_step_is_unknown` boolean，default `false`
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `sessions`
- N:1 -> `questions`
- N:1 -> `profiles`

---

### `public.session_questions`
**用途**：session 下发题目列表（顺序与快照）。

**字段**
- `session_id` uuid，FK -> `sessions.id`
- `question_id` uuid，FK -> `questions.id`
- `position` int
- `assigned_at` timestamptz，default `now()`

**约束**
- PK：`(session_id, question_id)`
- Unique：`(session_id, position)`

**关系**
- N:1 -> `sessions`
- N:1 -> `questions`

---

### `public.ai_explanations`
**用途**：题目 AI 讲解的缓存结果。

**字段**
- `question_id` uuid，PK，FK -> `questions.id`
- `content` text
- `model` text
- `prompt_version` text
- `cost_usd` numeric
- `created_at` timestamptz，default `now()`

**关系**
- 1:1 -> `questions`

---

## 视图

### `public.student_session_stats`
**用途**：按学生聚合的 session 统计（家长端仪表盘可用）。

**字段**
- `student_id`
- `total_sessions`
- `total_questions`
- `total_correct`
- `accuracy`

---

## 函数 / RPC

### `public.is_admin()`
**用途**：检查当前用户是否为 admin 角色，用于 RLS policies。

**返回**：boolean

---

### `public.handle_new_user()`
**用途**：auth trigger，注册时自动插入 `profiles` 行。

### `public.create_parent_invite(expires_in_hours int)`
**用途**：家长生成邀请码。

### `public.redeem_parent_invite(invite_code text)`
**用途**：学生兑换邀请码并建立关联。

### `public.get_parent_dashboard(target_student_id uuid, window_days int)`
**用途**：一次性返回家长端 dashboard payload（overview + trend + topics）。

---

### `public.start_practice_session(bank_slug text, override_limit int)`
**用途**：创建练习 session，按题库生成题目列表并返回（不包含答案）。

---

### `public.get_session_result(p_session_id uuid)`
**用途**：返回 session 结果详情（含题目、用户答案、正确答案、讲解）。

**鉴权**
- 使用 `SECURITY DEFINER`，函数内部检查 `session.student_id = auth.uid()`。
- 非所有者调用将抛出 `forbidden` 异常。

**返回结构**
```json
{
  "session_id": "uuid",
  "total_questions": 10,
  "correct_count": 7,
  "questions": [
    {
      "question_id": "uuid",
      "attempt_id": "uuid",
      "position": 1,
      "is_correct": true,
      "user_answer": "B",
      "correct_answer": "B",
      "stem": "题干文本",
      "options": [{"label": "A", "content": "..."}],
      "explanation": "讲解文本"
    }
  ]
}
```

---

### `public.import_questions(p_payload jsonb, p_partial boolean)`
**用途**：批量导入题目（含选项、标签）。

**鉴权**
- 需要 admin 角色。

**参数**
- `p_payload`：JSON 格式，包含 `questions` 数组
- `p_partial`：是否允许部分成功（默认 false，全部失败则回滚）

**返回结构**
```json
{
  "inserted_count": 10,
  "inserted_ids": ["uuid1", "uuid2"],
  "error_count": 0,
  "errors": []
}
```

---

### `public.import_questions_to_bank(p_payload jsonb, p_partial boolean, p_bank_id uuid)`
**用途**：批量导入题目并可选绑定到题库（按顺序追加）。

**鉴权**
- 需要 admin 角色。

**参数**
- `p_payload`：JSON 格式，包含 `questions` 数组
- `p_partial`：是否允许部分成功（默认 false，全部失败则回滚）
- `p_bank_id`：可选题库 ID；为空时仅导入题目

**返回结构**
```json
{
  "inserted_count": 10,
  "inserted_ids": ["uuid1", "uuid2"],
  "error_count": 0,
  "errors": []
}
```

---

### `public.reorder_bank_questions(p_bank_id uuid, p_items jsonb)`
**用途**：批量更新题库内题目的顺序。

**鉴权**
- 需要 admin 角色。

**参数**
- `p_bank_id`：题库 ID
- `p_items`：数组，每项包含 `question_id` 和 `position`

---

## Edge Functions

### `submit_attempt`
**用途**：服务端评分并保存学生作答记录。

**鉴权**
- 需要 `Authorization: Bearer <jwt>`。

**请求字段**
- `session_id` string (uuid)
- `question_id` string (uuid)
- `answer` string | number | null
- `duration_ms` number | null (optional)
- `skipped` boolean | null (optional)
- `student_selected_step_index` number | null (optional)
- `student_selected_step_is_unknown` boolean | null (optional)

**响应字段**
- `isCorrect` boolean
- `attemptId` string (uuid)

---

### `set_attempt_step`
**用途**：学生在错题后补充“卡点步骤”选择，写回 `attempts`，并尽量提前对应的 `ai_jobs` 运行时间。

**鉴权**
- 需要 `Authorization: Bearer <jwt>`。

**请求字段**
- `attempt_id` string (uuid)
- `student_selected_step_index` number | null
- `student_selected_step_is_unknown` boolean | null

**响应字段**
- `ok` boolean

---

### `coach_chat`
**用途**：学生向“全科老师总线程”发送一条消息（异步生成老师回复，支持流式更新）。

**鉴权**
- 需要 `Authorization: Bearer <jwt>`。

**请求字段**
- `text` string
- `linked_attempt_id` string (uuid) | null (optional)
- `reply_to_message_id` string (uuid) | null (optional)

**响应字段**
- `ok` boolean
- `userMessageId` string (uuid)

---

### `sign-asset-upload`
**用途**：为管理员生成图片上传签名 URL。

**鉴权**
- 需要 `Authorization: Bearer <jwt>`，且用户为 admin 角色。

**请求字段**
- `question_id` string (uuid)
- `file_name` string
- `content_type` string（支持：image/png, image/jpeg, image/gif, image/webp, image/svg+xml）

**响应字段**
- `signed_url` string（用于 PUT 上传）
- `storage_path` string（存储路径）
- `public_url` string（公开访问 URL）

---

## Storage Buckets

### `question-assets`
**用途**：存储题目图片/图表等资源。

**配置**
- 公开读取
- Admin 可上传/管理

---

## 显式索引
- `attempts_student_created_at_idx` on `attempts(student_id, created_at)`
- `attempts_client_submission_id_uidx` on `attempts(client_submission_id)`（unique, nullable）
- `sessions_student_created_at_idx` on `sessions(student_id, created_at)`
- `question_banks_active_order_idx` on `question_banks(is_active, sort_order)`
- `question_bank_questions_bank_position_idx` on `question_bank_questions(bank_id, position)`
- `session_questions_session_position_idx` on `session_questions(session_id, position)`
- `question_assets_pending_idx` on `question_assets(status, created_at)` where `status = 'pending'`
- `procedures_subject_status_idx` on `procedures(subject, status)`
- `procedures_search_trgm_idx` on `procedures(search_text)` (GIN trigram)
- `attempt_insights_student_procedure_step_idx` on `attempt_insights(student_id, procedure_id, error_step_index, created_at)`
- `attempt_insights_student_created_at_idx` on `attempt_insights(student_id, created_at)`
- `coach_thread_messages_student_created_at_idx` on `coach_thread_messages(student_id, created_at)`
- `coach_thread_messages_reply_to_idx` on `coach_thread_messages(reply_to_message_id)`
- `ai_jobs_attempt_insight_unique` on `ai_jobs(attempt_id)` where `kind = 'attempt_insight'`
- `ai_jobs_status_run_after_idx` on `ai_jobs(status, run_after)`
- `ai_jobs_kind_dedupe_key_unique` on `ai_jobs(kind, dedupe_key)` where `dedupe_key is not null`
- `student_reports_student_created_at_idx` on `student_reports(student_id, created_at desc)`
- `push_tokens_student_idx` on `push_tokens(student_id, updated_at)`
- `notification_events_status_idx` on `notification_events(status, created_at)`
- `notification_events_status_updated_at_idx` on `notification_events(status, updated_at)`

---

## AI Coach（新增，MVP）

### `public.procedures`
**用途**：AI 自增长的“解题套路库”（SAT Math 先行），用于按步骤相似检索。

**字段**（摘要）
- `id` uuid, PK
- `subject` text
- `name` text
- `steps` jsonb（3–7 步短句）
- `steps_version` int
- `aliases` text[]
- `status` text（active|merged|deprecated）
- `merged_into` uuid
- `search_text` text（name + aliases，用于 trigram 搜索；由 trigger 自动维护）

---

### `public.attempt_insights`
**用途**：错题的结构化诊断结果（procedure + step + error_mode + short explanation + followups）。

**字段**（摘要）
- `attempt_id` uuid, PK
- `student_id` uuid
- `question_id` uuid
- `procedure_id` uuid
- `error_step_index` int
- `student_selected_step_index` int / `student_selected_step_is_unknown` boolean
- `error_mode_enum` text + `error_mode_detail` text
- `evidence` jsonb
- `explanation_short` text
- `followups` jsonb

---

### `public.student_snapshots`
**用途**：学生长期状态快照（跨题对话注入用）。

---

### `public.student_reports`
**用途**：周报/月报存档（阶段对比 + 下一步学习计划）。

**字段**（摘要）
- `id` uuid, PK
- `student_id` uuid
- `period_kind` text (`weekly` | `monthly`)
- `period_key` text（去重键）
- `period_start` / `period_end` timestamptz
- `metrics` jsonb
- `delta` jsonb
- `summary` text
- `plan` jsonb
- `model` text
- `prompt_version` text
- `cost_usd` numeric

**约束**
- unique `(student_id, period_key)`

---

### `public.coach_thread_messages`
**用途**：一人一个“全科老师总线程”的对话消息存档（允许跨题）。

**字段（摘要）**
- `id` uuid, PK
- `student_id` uuid
- `role` text (`user` | `assistant` | `tool`)
- `content` jsonb
- `linked_attempt_id` uuid | null
- `reply_to_message_id` uuid | null
- `created_at` timestamptz

---

### `public.coach_memory_entries`
**用途**：王校长长期记忆（daily + curated）。

**字段**（摘要）
- `id` uuid, PK
- `student_id` uuid
- `scope` text (`daily` | `curated`)
- `content` text
- `tags` text[]
- `source` text
- `created_at` timestamptz

---

### `public.ai_jobs`
**用途**：异步任务队列（`attempt_insight` / `coach_reply` / `snapshot_refresh` / `progress_report` 等）。

**字段**（摘要）
- `kind` text
- `dedupe_key` text（可空，同类任务去重）

---

## AI Coach Config（Admin）

### `public.ai_prompt_configs`
**用途**：AI Coach 的 prompt + model 配置（支持版本化与发布）。

**字段**（摘要）
- `id` uuid, PK
- `kind` text (`attempt_insight` | `coach_reply` | `progress_report`)
- `prompt_version` text
- `system_prompt` text
- `model_provider` text (`minimax` | `openai` | `openrouter`)
- `model_id` text
- `status` text (`draft` | `published` | `archived`)
- `created_by` uuid (auth.users)
- `created_at` / `updated_at` / `published_at` timestamptz

**约束**
- 每个 `kind` 仅允许一个 `published` 版本（partial unique index）

---

### `public.ai_provider_keys`
**用途**：第三方模型 provider key（仅服务端读取）。

**字段**（摘要）
- `provider` text (`openrouter`)
- `api_key` text
- `created_by` / `updated_by` uuid
- `created_at` / `updated_at` timestamptz

---

### `public.ai_agent_logs`
**用途**：AI Coach agent 执行日志（prompt + tool 轨迹）。

**字段**（摘要）
- `job_id` uuid
- `kind` text
- `student_id` uuid
- `attempt_id` uuid
- `model_provider` text
- `model_id` text
- `prompt_version` text
- `system_prompt` text
- `prompts` jsonb
- `events` jsonb
- `status` text (`done` | `error`)
- `error` text
- `created_at` timestamptz

---

### `public.push_tokens`
**用途**：设备推送 token（APNs/FCM）存储。

**字段**（摘要）
- `id` uuid, PK
- `student_id` uuid
- `device_token` text
- `platform` text (`apns` | `fcm`)
- `last_seen_at` timestamptz

---

### `public.notification_events`
**用途**：推送通知待发送队列（由 worker 入队）。

**字段**（摘要）
- `id` uuid, PK
- `student_id` uuid
- `event_type` text (`attempt_insight_ready` | `coach_reply_ready` | `progress_report_ready`)
- `payload` jsonb
- `status` text (`queued` | `sending` | `sent` | `error`)
- `locked_at` timestamptz
- `locked_by` text

---

## Admin

### `public.admin_audit_logs`
**用途**：Admin 操作审计日志（短期保留）。

**字段**（摘要）
- `id` uuid, PK
- `actor_id` uuid
- `actor_email` text
- `action` text
- `resource_type` text
- `resource_id` text
- `metadata` jsonb
- `created_at` timestamptz

---

## AI Coach 函数 / 触发器（新增）

### `public.enqueue_attempt_insight_job()`
**用途**：attempt insert 后（且 `is_correct=false`）自动插入 `ai_jobs(kind='attempt_insight')`。

### `public.claim_ai_jobs(p_worker_id text, p_limit int, p_kinds text[] default null)`
**用途**：worker 原子性 claim `ai_jobs`（`queued` -> `running`，`for update skip locked`）。`p_kinds` 可选，用于仅领取指定 kind 的任务。

### `public.search_procedure_candidates(p_subject text, p_query text, p_limit int)`
**用途**：基于 trigram 相似度检索 procedure 候选（用于“先检索再创建”的护栏）。

### `public.get_attempt_for_coach(p_attempt_id uuid)`
**用途**：仅供 service role 读取 attempt + question（含 stem/options/answer_key/tags），用于生成错题讲解。

### `public.get_student_period_stats(p_student_id uuid, p_start timestamptz, p_end timestamptz)`
**用途**：生成学生周期统计（attempts / mistakes / coverage），仅 service role 可调用。

### `public.list_active_students(p_since timestamptz)`
**用途**：返回近 N 天有练习记录的学生，用于定期报告调度。

### `public.claim_notification_events(p_worker_id text, p_limit int)`
**用途**：通知发送 worker 原子性 claim `notification_events`（`queued` -> `sending`）。
