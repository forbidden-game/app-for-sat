# AI Coach v2 API & Jobs Spec

日期：2026-01-22

目标：实现“主动推送 + 长期画像 + 记忆优先”的学生一对一老师系统（每个学生一个 AI 老师）。

本文件用于实现阶段的统一契约（DB/RPC/Jobs/Worker/Prompt），覆盖触发条件、工作流程、数据结构与错误处理。

---

## 1. 核心能力

1. 周期性进展报告

- 周报/月报（默认：最近 7/30 天 vs 上一阶段对比）
- 自动写入 `student_reports`，并入队 `notification_events`

2. 长期画像刷新

- 周期性刷新 `student_snapshots.recent_trend` 与 Top 弱点
- 为对话提供长期记忆与趋势

3. 记忆优先对话

- Coach 回复优先注入：`student_snapshots` + 最近 `student_reports`
- 需要历史错题时，再检索 `attempt_insights`

4. 多模型流水线（按任务配置）

- attempt_insight / coach_reply / progress_report 可配置不同模型

---

## 2. 数据模型（概要）

### 2.1 `public.student_reports`

用途：周报/月报存档（包含阶段对比与下一步学习计划）。

字段：

- `id` uuid PK default `gen_random_uuid()`
- `student_id` uuid not null FK -> `profiles.id`
- `period_kind` text not null (weekly|monthly)
- `period_key` text not null（去重键，如 weekly-2026-01-14）
- `period_start` timestamptz not null
- `period_end` timestamptz not null
- `metrics` jsonb not null（当前阶段统计）
- `delta` jsonb not null（与上一阶段对比）
- `summary` text not null（老师口吻总结）
- `plan` jsonb not null（下一步计划，结构化）
- `model` text
- `prompt_version` text
- `cost_usd` numeric
- `created_at` timestamptz default now()

约束/索引：

- unique(student_id, period_key)
- index(student_id, created_at desc)

### 2.2 `public.ai_jobs`

用途：异步任务队列（错题讲解、对话回复、快照刷新、报告生成等）。

关键字段：

- `id` uuid PK default `gen_random_uuid()`
- `kind` text（attempt_insight|thread_summary|procedure_merge|coach_reply|snapshot_refresh|progress_report）
- `status` text（queued|running|done|error）
- `attempt_id` uuid nullable
- `student_id` uuid nullable
- `payload` jsonb not null
- `run_after` timestamptz not null（延迟执行）
- `locked_at` timestamptz nullable
- `locked_by` text nullable
- `dedupe_key` text nullable（同类任务去重）
- `attempt_count` int default 0
- `error` text nullable（当前 error）
- `last_error` text nullable
- `last_error_at` timestamptz nullable
- `last_error_code` text nullable
- `completed_at` timestamptz nullable
- `created_at`/`updated_at`

约束/索引：

- unique(kind, dedupe_key) where dedupe_key is not null
- index(status, run_after)
- index(status, updated_at)

### 2.3 `public.notification_events`

用途：通知发送队列。

关键字段：

- `id` uuid PK
- `student_id` uuid not null
- `event_type` text（progress_report_ready 等）
- `payload` jsonb
- `status` text（queued|sending|sent|error）
- `error` text nullable
- `locked_at` timestamptz nullable
- `locked_by` text nullable
- `created_at`/`updated_at`

---

## 3. RPC / SQL 函数（关键）

### 3.1 `claim_ai_jobs(p_worker_id, p_limit, p_kinds)`

用途：领取 `ai_jobs`。

行为：

- 仅 service_role 可调用
- 选择 `status=queued` 且 `run_after <= now()`
- 跳过被锁定且 10 分钟内未过期的记录
- 更新为 `running`，写入 `locked_at` / `locked_by`，并 `attempt_count + 1`

### 3.2 `get_student_period_stats(p_student_id, p_start, p_end)`

用途：生成报告/快照的结构化指标。

### 3.3 `list_active_students(p_since)`

用途：拉取近 N 天有练习记录的学生列表（调度用）。

### 3.4 `claim_notification_events(p_worker_id, p_limit)`

用途：通知发送 worker 领取 `notification_events`。

行为：

- 领取 `status=queued`
- 或 `status=sending` 且超过 10 分钟未更新的记录（视作超时重试）
- 标记为 `sending` 并写入锁定信息

---

## 4. Job 设计（payload + 处理流程）

### 4.1 `attempt_insight`

触发：`attempts.is_correct = false` 且写入后。

payload：

- `attempt_id`

处理流程：

1. 拉取 attempt + question + tags + 快照/历史
2. 搜索/创建 procedure
3. 检索相似错误
4. 生成短讲解 + 追问
5. 写入 `attempt_insights`
6. 触发快照刷新（入队或工具内补写）

特殊条件：

- 若 `student_selected_step_index` 缺失且 `unknown` 未标记，会短暂 defer（默认 2 分钟内每 15 秒重试）

### 4.2 `coach_reply`

触发：学生在总线程发消息。

payload：

- `user_message_id`（可选）
- `linked_attempt_id`（可选）

处理流程：

1. 拉取消息上下文（最近对话 + 快照 + 报告 + 历史 insights）
2. 生成回复并流式写入 assistant message
3. 失败时写入兜底回复并标记错误

### 4.3 `snapshot_refresh`

payload：

- `student_id`
- `period_end` (optional)

处理流程：

- 调用 `get_student_period_stats`（7/30/90 天）
- 更新 `student_snapshots`（weak_procedures_top/weak_steps_top/common_error_modes_top/recent_trend）

### 4.4 `progress_report`

payload：

- `student_id`
- `period_kind` (weekly|monthly)
- `period_key`
- `period_start`
- `period_end`

处理流程：

1. 如果 `student_reports` 已存在同 period_key，直接跳过
2. 生成当前期 + 上期 stats
3. LLM 生成 summary + plan（失败则 fallback 模板）
4. 写入 `student_reports`
5. enqueue `notification_events`（progress_report_ready）

---

## 5. Worker 行为

### 5.1 coach-service worker 触发与条件

- 启动后循环轮询
- `AI_COACH_ENABLE_SCHEDULER=true` 时，按 `AI_COACH_SCHEDULE_INTERVAL_MS` 调度
- 领取条件：`status=queued` 且 `run_after <= now()` 且锁过期
- 支持 `AI_COACH_JOB_KINDS` 过滤处理范围
- 并发：最多 `AI_COACH_MAX_CONCURRENCY` 个 job 同时处理；每次 claim 不超过 `AI_COACH_CLAIM_LIMIT`

### 5.2 Job 生命周期

- claim：`queued -> running`，写入 `locked_at` / `locked_by`，`attempt_count+1`
- success：`running -> done`，清理 error 字段，写入 `completed_at`
- error：`running -> error`，写入 `error/last_error/last_error_code/last_error_at`
- defer：通过 `JobDeferredError` 将 `status` 重置为 `queued`，`run_after` 延后，并清理锁

### 5.3 调度器（scheduler）

- 调用 `list_active_students` 获取近 N 天活跃学生
- 为每位学生入队 `snapshot_refresh` + `progress_report`（weekly/monthly）
- 使用 `dedupe_key` 去重；批量 upsert 插入

### 5.4 graceful shutdown

- 处理 SIGTERM/SIGINT：停止 claim，新任务不再进入；等待 in-flight 完成

---

## 6. Notification Sender Worker

- 领取 `notification_events`（queued 或超时 sending）
- `mode=log` 时仅记录；后续可接入真实推送
- 发送成功：`status=sent`
- 失败：`status=error` 并记录 message

---

## 7. 环境变量（关键）

- `AI_COACH_ENABLE_SCHEDULER`
- `AI_COACH_POLL_INTERVAL_MS`
- `AI_COACH_CLAIM_LIMIT`
- `AI_COACH_MAX_CONCURRENCY`
- `AI_COACH_JOB_KINDS`
- `AI_COACH_MODEL_DEFAULT/INSIGHT/CHAT/REPORT`
- `MINIMAX_API_KEY`（只有当启用的 job 需要 minimax 模型时才强制）

通知发送：

- `NOTIFICATION_SENDER_POLL_INTERVAL_MS`
- `NOTIFICATION_SENDER_CLAIM_LIMIT`
- `NOTIFICATION_SENDER_MAX_CONCURRENCY`
- `NOTIFICATION_SENDER_MODE`

---

## 8. Notification 约定

- `progress_report_ready` payload: { student_id, report_id, period_kind, period_start, period_end }

---

## 9. Prompt 版本策略

- `attempt_insight`: `ai-coach-insight-v2`
- `coach_reply`: `ai-coach-chat-v2`
- `progress_report`: `ai-coach-report-v1`

版本写入 `student_reports.prompt_version` / `attempt_insights.prompt_version`。
