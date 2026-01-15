---
summary: AI Coach v1 architecture (agent-first, tool-driven, decoupled)
read_when: designing AI coach system architecture, tools, or context pipeline
---

# AI Coach Architecture v1 (Agent-first, Tool-driven)
日期：2026-01-16

北极星：每个学生一个长期 AI 老师。自由度高、工具充分、长期记忆稳定。

## 设计原则
1) Agent 自由度优先：不给强输出模板，给清晰工具和上下文。
2) 工具小而稳：命名直觉、参数稳定、返回可复用。
3) 上下文轻而准：只提供关键事实 + 情境信号，避免噪音。
4) 解耦：业务流程、工具实现、模型选择分离。
5) 可维护：工具接口稳定，内部实现可替换。

## 核心组件
1) Context Orchestrator（上下文编排）
   - 输入：student_id、会话/attempt 线索
   - 输出：Context Packet（轻量 JSON）
   - 只做检索与聚合，不做“决策”

2) Tool Gateway（工具层）
   - 统一工具清单 + schema
   - 读写分离：read tools / write tools
   - 与数据库和外部服务隔离

3) Skill Layer（技能库）
   - 以 SKILL.md 组织
   - prompt 只给技能目录；细节按需读取

4) Coach Agent（王校长）
   - 主动决定是否调用工具
   - 可跨题、多轮、长期记忆

5) Storage（Supabase）
   - attempts / attempt_insights / procedures / student_snapshots / coach_thread_messages

## 统一上下文：Context Packet
最小但足够：

```json
{
  "student": {
    "id": "...",
    "timezone": "...",
    "recent_accuracy": 0.62,
    "stress_hint": "high|medium|low|unknown",
    "time_of_day": "morning|afternoon|evening|night"
  },
  "attempt": {
    "id": "...",
    "linked": true,
    "student_selected_step_index": 2,
    "student_selected_step_is_unknown": false
  },
  "question": { "stem": "...", "options": ["A...","B..."] },
  "snapshot": { "weak_procedures_top": [], "recent_trend": {} },
  "recent_insights": [ ... ],
  "recent_messages": [ ... ]
}
```

## 两条场景（共用同一 Agent）
1) 日常提问
   - 无 attempt 或弱关联
   - 仍注入 student_snapshot + recent_insights

2) 错题追问
   - linked_attempt_id 进入 Context Packet
   - 自动带入 attempt + question + insight

## 工具清单（v1 草案）
读工具（context）：
- `get_attempt_context(attempt_id)` → attempt + question + tags
- `get_student_snapshot(student_id)` → snapshot
- `search_similar_mistakes(student_id, procedure_id, step)` → history
- `search_procedure_candidates(subject, query)` → procedures

写工具（memory）：
- `write_attempt_insight(...)` → attempt_insights
- `append_coach_thread_messages(...)` → coach_thread_messages
- `write_student_note(student_id, note)` → lightweight coach memory (optional)

工具原则：
- schema 稳定
- 返回可复用
- 命名动作化

## Skills（组织方式）
建议目录：`ai-coach/skills/`
- `coach-core`：老师思路与风格
- `sat-math-procedures`：套路与步骤语料
- `error-modes`：错误类型解释
- `care-tone`：情境关怀提示
- `study-plan`：学习计划建议

## 解耦点
- Context Orchestrator 与 Agent 解耦（只给事实，不干预决策）
- Tool Gateway 与数据库解耦（接口固定，内部可替换）
- Skills 与 Prompt 解耦（按需加载）

## 与现有系统映射
- `get_attempt_for_coach` RPC → `get_attempt_context`
- `attempt_insights` 表 → `write_attempt_insight`
- `coach_thread_messages` 表 → `append_coach_thread_messages`
- `student_snapshots` 表 → `get_student_snapshot`

## 评价基准（仅观察）
- 工具调用率（按场景）
- insight 写入成功率
- 对话可追问率（用户继续回复比例）
- 平均响应长度（是否过长）
