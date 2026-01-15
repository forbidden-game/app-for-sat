---
summary: AI Coach memory v1 (long-term teacher memory, tool-accessed)
read_when: designing memory, embeddings, or coach tools
---

# AI Coach Memory v1
日期：2026-01-16

目标：让王校长具备长期记忆，但不强制结构化输出；记忆由工具存取，按需检索。

## 核心设计
1) **两层记忆**（参考 clawdbot）
   - `Daily Memory`：追加式、按天记录（学生近期状态与事件）
   - `Curated Memory`：精选长期事实（偏好、长期薄弱点、关键目标）

2) **工具驱动**：不自动灌入上下文，靠 `memory_search` / `memory_get` 主动检索。

3) **轻触发**：只“提示可记忆”，不强制写入。

## 数据结构（建议）
### A) coach_memory_entries（daily）
- `id` uuid PK
- `student_id` uuid
- `scope` text (daily|curated)
- `content` text
- `tags` text[] (optional)
- `source` text (chat|attempt|report|manual)
- `created_at` timestamptz

### B) coach_memory_embeddings（optional）
- `memory_id` uuid FK -> coach_memory_entries.id
- `embedding` vector (pgvector)
- `model` text
- `created_at` timestamptz

> 若暂时不做向量，先用 trigram/tsvector 搜索，接口不变。

## 工具（v1）
读：
- `memory_search(student_id, query, limit)` → 匹配的 memory_id + 摘要
- `memory_get(memory_id)` → 取完整 content

写：
- `memory_write(student_id, scope, content, tags?, source?)`

> 只有这些就够：少而稳。

## 触发策略（软）
- 当对话中出现“长期事实”时，模型可选择 `memory_write`。
- 不要求每次写；质量优先。

## 与现有表的关系
- `student_snapshots` = 结构化统计（客观）
- `coach_memory_entries` = 教师笔记（主观）
- 两者并存，互补。

## 未来可扩展（不在 v1 强制）
- memory summary job（周期性压缩 daily）
- memory conflict resolution（相互矛盾的记忆提醒）
- memory access policy（敏感信息分层）
