# Agent Tools（pi-agent-core / pi-ai）
日期：2026-01-14

北极星：工具约束服务于“每个学生一个 AI 老师”的长期记忆与可追问讲解。

本页定义 Coach Service 需要暴露给 LLM 的核心工具（tool calling），用于强制“先检索、再回答、再写回”。

实现建议：
- 使用 `@mariozechner/pi-ai` 的 TypeBox schema 定义 tools，避免自由文本输出。
- 服务端在执行工具时：严格鉴权（student_id 只能访问自己的数据）。

## Tool 1: `search_procedure_candidates`
用途：在创建新 procedure 之前，先检索已有 procedure 候选，防止碎片化。

输入：
- `subject`: `sat_math`
- `query`: 由题干/选项/目标/粗解法摘要构成的短文本

输出：
- `candidates[]`: `{ procedure_id, name, similarity, steps_version, steps[] }`

## Tool 2: `create_procedure`
用途：当没有候选足够相似时，创建新的 procedure。

输入：
- `subject`, `name`, `description`, `steps[]`

输出：
- `procedure_id`, `steps_version`

规则：
- 仅当 `search_procedure_candidates` topK 都低于阈值才允许创建。

## Tool 3: `merge_procedures`
用途：合并重复 procedure，保留 aliases。

输入：
- `from_procedure_id`, `to_procedure_id`, `rationale`

输出：
- `ok`

## Tool 4: `search_similar_mistakes`
用途：按步骤相似检索该学生历史错误。

输入：
- `student_id`
- `procedure_id`
- `error_step_index`
- `limit`

输出：
- `matches[]`: `{ attempt_id, created_at, error_step_index, error_mode_enum, explanation_short, student_selected_step_index, student_selected_step_is_unknown }`

排序建议：
1) 同 step
2) 同 error_mode_enum（加权）
3) 最近时间

## Tool 5: `get_student_snapshot`
用途：加载长期快照（跨题对话必须用）。

输入：
- `student_id`

输出：
- `snapshot`: `{ weak_steps_top, common_error_modes_top, recent_trend, notes }`

## Tool 6: `write_attempt_insight`
用途：把本次错题的结构化诊断写回 DB，并触发更新快照。

输入（核心字段）：
- `attempt_id`
- `procedure_id`, `procedure_steps_version`
- `error_step_index`
- `error_mode_enum`, `error_mode_detail?`
- `evidence`
- `explanation_short`
- `followups`
- `confidence`
- `model`, `prompt_version`, `cost_usd`

输出：
- `ok`

## Tool 7（对话）: `append_coach_thread_messages`
用途：追加对话消息（user/assistant/tool）。

输入：
- `student_id`, `messages[]`

输出：
- `ok`

## Tool 8（可选）: `summarize_thread`
用途：对旧消息做摘要并存储（降低上下文成本）。

输入：
- `student_id`, `until_message_id`

输出：
- `summary_text` 或 `summary_json`
