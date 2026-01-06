# Supabase Schema（MVP）

日期：2026-01-06

## 总览
- 表数量：16
- 视图数量：1
- 函数/RPC：9（1 个 auth hook、2 个邀请 RPC、1 个家长端聚合 RPC、2 个练习 session RPC、1 个 admin helper、2 个题库管理 RPC）

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

**响应字段**
- `isCorrect` boolean

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
- `sessions_student_created_at_idx` on `sessions(student_id, created_at)`
- `question_banks_active_order_idx` on `question_banks(is_active, sort_order)`
- `question_bank_questions_bank_position_idx` on `question_bank_questions(bank_id, position)`
- `session_questions_session_position_idx` on `session_questions(session_id, position)`
- `question_assets_pending_idx` on `question_assets(status, created_at)` where `status = 'pending'`
