# Supabase Schema（MVP）

日期：2026-01-05

## 总览
- 表数量：11
- 视图数量：1
- 函数/RPC：4（1 个 auth hook、2 个邀请 RPC、1 个家长端聚合 RPC）

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

### `public.questions`
**用途**：题库主表（题干、答案、元数据）。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `subject` text
- `module` text
- `difficulty` int
- `question_type` text，enum：`mcq|numeric`
- `stem` text
- `answer_key` jsonb
- `metadata` jsonb，default `{}`
- `created_at` timestamptz，default `now()`

**关系**
- 1:N -> `question_options`
- N:M -> `tags`（通过 `question_tags`）
- 1:N -> `question_assets`

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
- `name` text
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
- `asset_url` text
- `asset_type` text
- `created_at` timestamptz，default `now()`

**关系**
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
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `profiles`
- 1:N -> `attempts`

---

### `public.attempts`
**用途**：单题作答记录。

**字段**
- `id` uuid，PK，default `gen_random_uuid()`
- `session_id` uuid，FK -> `sessions.id`
- `question_id` uuid，FK -> `questions.id`
- `student_id` uuid，FK -> `profiles.id`
- `answer` jsonb
- `is_correct` boolean
- `duration_ms` int
- `skipped` boolean，default `false`
- `created_at` timestamptz，default `now()`

**关系**
- N:1 -> `sessions`
- N:1 -> `questions`
- N:1 -> `profiles`

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

### `public.handle_new_user()`
**用途**：auth trigger，注册时自动插入 `profiles` 行。

### `public.create_parent_invite(expires_in_hours int)`
**用途**：家长生成邀请码。

### `public.redeem_parent_invite(invite_code text)`
**用途**：学生兑换邀请码并建立关联。

### `public.get_parent_dashboard(target_student_id uuid, window_days int)`
**用途**：一次性返回家长端 dashboard payload（overview + trend + topics）。

---

## 显式索引
- `attempts_student_created_at_idx` on `attempts(student_id, created_at)`
- `sessions_student_created_at_idx` on `sessions(student_id, created_at)`
