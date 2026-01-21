# Flows（MVP + v2）
日期：2026-01-22

北极星：每个学生一个 AI 老师（错题讲解 + 追问对话 + 长期追踪）。以下流程以此为中心。

## A) 错题处理流（attempt -> insight）
触发：`attempts.is_correct = false` 写入后。

1. 收集上下文
- `attempt`: answer、duration、student_id、question_id
- `question`: stem、options、正确答案（服务端可取）
- `tags`: 知识点标签
- iOS 额外采集：`student_selected_step_index` 或 `unknown`

2. Procedure 决策（先检索再创建）
- 工具：`search_procedure_candidates()`
- 若命中高相似候选：选定 `procedure_id`
- 否则：`create_procedure()` 生成新 procedure（steps_version=1）

3. 相似错误检索（针对该学生）
- 强匹配：同 `procedure_id + error_step_index`
- 次匹配：同 procedure 不同步
- 输出 topK 证据（attempt_id、当时卡点步、当时 error_mode_enum、当时 followups 等）

4. 生成输出（短讲解 + 追问）
- 若强匹配命中：重点讲解（对比历史错法，给更窄训练建议）
- 否则：首次讲解（建档）

5. 写回
- `write_attempt_insight()`
- 触发 `snapshot_refresh`（入队或工具内更新）

特殊条件：
- 若 `student_selected_step_index` 缺失且 `unknown` 未标记，会短暂 defer（默认 2 分钟内每 15 秒重试）

## B) 总线程对话流（chat -> response）
触发：学生在“全科老师总线程”发消息（可跨题）。

1. 获取短期上下文
- 最近 N 条 `coach_thread_messages`
- 若用户消息带 `linked_attempt_id`，额外取该 attempt 的题目上下文

2. 获取长期记忆
- 快照：`student_snapshots`
- 最近报告：`student_reports`
- 必要时检索历史错题：`attempt_insights`

3. 回答策略（短 + 可追问）
- 默认：先问 1 个澄清问题或给 1 个最小可执行建议
- 避免一次性长解析；引导学生“说出你的第 X 步是怎么做的”

4. 写回对话
- 追加写入 `coach_thread_messages`
- 可异步生成 `thread_summary`（压缩旧消息）

## C) Procedure 去重/合并（后台维护）
触发：
- 定时任务，或当 `create_procedure` 频繁出现相似名字/steps 时。

流程：
- `search_procedure_candidates` 找近邻
- AI 产出 `merge_procedures(from,to,rationale)` 建议
- MVP 可先人工审核；后续可自动合并（保留 aliases）

## D) 快照刷新流（snapshot_refresh）
触发：
- 调度器批量入队
- 或 `write_attempt_insight` 后触发

流程：
1) 拉取 7/30/90 天 stats（`get_student_period_stats`）
2) 更新 `student_snapshots`（Top 弱点 + recent_trend）

## E) 报告生成流（progress_report）
触发：调度器批量入队。

流程：
1) 检查 `student_reports` 是否已存在同 `period_key`
2) 生成当前期 + 上一期 stats
3) LLM 生成 summary + plan（失败走 fallback）
4) 写入 `student_reports`
5) 入队 `notification_events`（progress_report_ready）

## F) 通知发送流（notification_events）
触发：progress_report 写入后入队。

流程：
1) Notification sender 领取 `notification_events`
2) 查询 `push_tokens`
3) 发送成功 -> `sent`，失败 -> `error`

---

## Worker 触发条件（摘要）

### coach-service worker
- 轮询 `ai_jobs`（`status=queued` + `run_after <= now()`）
- 锁过期窗口 10 分钟
- 调度器周期性入队快照与报告任务
- 并发受 `AI_COACH_MAX_CONCURRENCY` 限制

### notification-sender worker
- 轮询 `notification_events`（`queued` 或超时 `sending`）
- 并发受 `NOTIFICATION_SENDER_MAX_CONCURRENCY` 限制
