# Supabase Schema（MVP）

日期：2026-01-06

## 总览
- 表数量：14
- 视图数量：1
- 函数/RPC：6（1 个 auth hook、2 个邀请 RPC、1 个家长端聚合 RPC、2 个练习 session RPC）

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
- 使用 `SECURITY INVOKER` + RLS，调用者必须是 session 所有者（`session.student_id = auth.uid()`）。
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

**字段说明**
- `is_correct`：若用户未作答或跳过，返回 `false`
- `user_answer`：若用户跳过或无 attempt 记录，返回 `null`
- `correct_answer`：从 `questions.answer_key->'correct'` 提取
- `explanation`：优先取 `ai_explanations.content`，无则返回空字符串
- `questions` 按 `session_questions.position` 升序排列

---

## Edge Functions

### `submit_attempt`
**用途**：服务端评分并保存学生作答记录。根据 `question_id` 读取答案，写入 `attempts`，并在该题目首次作答正确时递增 `sessions.correct_count`（重复提交只存 attempts，不重复计分）。

**鉴权**
- 需要 `Authorization: Bearer <jwt>`。

**请求字段**
- `session_id` string (uuid)
- `question_id` string (uuid)
- `answer` string | number | null
- `duration_ms` number | null (optional)
- `skipped` boolean | null (optional)

**响应字段**
- `isCorrect` boolean

**示例**
```json
{
  "session_id": "9b4638c3-1a3a-4d1b-9d7a-9aa5c94a1b2c",
  "question_id": "ae5e7f6b-2ed2-4f0f-b38a-986c9a0a2f2c",
  "answer": "B",
  "duration_ms": 12000,
  "skipped": false
}
```

## 显式索引
- `attempts_student_created_at_idx` on `attempts(student_id, created_at)`
- `sessions_student_created_at_idx` on `sessions(student_id, created_at)`
- `question_banks_active_order_idx` on `question_banks(is_active, sort_order)`
- `question_bank_questions_bank_position_idx` on `question_bank_questions(bank_id, position)`
- `session_questions_session_position_idx` on `session_questions(session_id, position)`
