# Flows（MVP）
日期：2026-01-14

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
- 更新 `student_snapshot`

## B) 总线程对话流（chat -> response）
触发：学生在“全科老师总线程”发消息（可跨题）。

1. 获取短期上下文
- 最近 N 条 `coach_thread_messages`
- 若用户消息带 `linked_attempt_id`，额外取该 attempt 的题目上下文

2. 获取长期记忆
- 工具：`get_student_snapshot(student_id)`
- 如需要引用历史相似错误：`search_similar_mistakes(...)`

3. 回答策略（短 + 可追问）
- 默认：先问 1 个澄清问题或给 1 个最小可执行建议
- 避免一次性长解析；必要时引导学生“说出你的第 X 步是怎么做的”

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
