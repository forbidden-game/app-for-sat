# AI Coach v2 API & Jobs Spec

目标：实现“主动推送 + 长期画像 + 记忆优先”的学生一对一老师系统。

本文件用于实现阶段的统一契约（DB/RPC/Jobs/Worker/Prompt）。

## 1. 新增/调整的核心能力

1) 周期性进展报告
- 周报/月报（默认：最近 7/30 天 vs 上一阶段对比）
- 自动写入 `student_reports`，并入队 `notification_events`

2) 长期画像刷新
- 周期性刷新 `student_snapshots.recent_trend` 与 Top 弱点
- 为对话提供长期记忆与趋势

3) 记忆优先对话
- Coach 回复优先注入：`student_snapshots` + 最近 `student_reports`
- 需要历史错题时，再检索 `attempt_insights`

4) 多模型流水线（按任务配置）
- attempt_insight / coach_reply / progress_report 可配置不同模型

---

## 2. 数据模型（新增）

### 2.1 `public.student_reports`
用途：周报/月报存档（包含阶段对比与下一步学习计划）。

字段建议：
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

RLS：
- 学生可读自己
- service role 可写

### 2.2 `public.ai_jobs` 扩展
新增 `kind`：
- `snapshot_refresh`：刷新 student_snapshots
- `progress_report`：生成周/月报

可选新增字段：
- `dedupe_key` text nullable（同类任务去重用）
- unique(kind, dedupe_key) where dedupe_key is not null

### 2.3 `public.notification_events` 扩展
新增 `event_type`：
- `progress_report_ready`

---

## 3. RPC / SQL 函数（新增）

### 3.1 `get_student_period_stats(p_student_id, p_start, p_end)`
用途：生成报告/快照的结构化指标。
返回 jsonb：
- attempts: total, correct, accuracy, avg_duration_ms, skipped
- mistakes: top_procedures, top_steps, top_error_modes
- coverage: subjects/tags 分布（可选）

权限：service_role only。

### 3.2 `list_active_students(p_since)`
用途：拉取近 N 天有练习记录的学生列表（调度用）。
权限：service_role only。

### 3.3 `claim_notification_events(p_worker_id, p_limit)`
用途：通知发送 worker 领取 `notification_events`。
权限：service_role only。

---

## 4. Job 设计

### 4.1 `snapshot_refresh`
payload:
- student_id
- period_end (optional)

动作：
- 调用 `get_student_period_stats`（7/30/90 天）
- 更新 `student_snapshots`（weak_procedures_top/weak_steps_top/common_error_modes_top/recent_trend）

### 4.2 `progress_report`
payload:
- student_id
- period_kind (weekly|monthly)
- period_key
- period_start
- period_end

动作：
- 取当前期 + 上一期 stats
- 生成 summary + plan（LLM）
- 写入 `student_reports`
- enqueue `notification_events` with `progress_report_ready`

---

## 5. Worker 行为（ai-coach/coach-service）

- 继续处理：`attempt_insight`, `coach_reply`
- 新增处理：`snapshot_refresh`, `progress_report`
- 内部调度：定期扫描活跃学生并插入新 report jobs

### 5.1 模型配置（环境变量）
- `AI_COACH_MODEL_DEFAULT`：默认模型（如 `minimax/MiniMax-M2.1`）
- `AI_COACH_MODEL_INSIGHT`
- `AI_COACH_MODEL_CHAT`
- `AI_COACH_MODEL_REPORT`

---

## 6. 客户端 API（读）

- `student_snapshots`：直接 select（RLS）
- `student_reports`：按 `student_id + period_kind` 拉取最近 N 条

---

## 7. Notification 约定

- `progress_report_ready` payload: { student_id, report_id, period_kind, period_start, period_end }

---

## 8. Prompt 版本策略

- `attempt_insight`: `ai-coach-insight-v2`
- `coach_reply`: `ai-coach-chat-v2`
- `progress_report`: `ai-coach-report-v1`

版本写入 `student_reports.prompt_version` / `attempt_insights.prompt_version`。
