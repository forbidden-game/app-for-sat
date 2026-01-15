---
summary: AI Coach tool + context test plan (v1)
read_when: validating coach context/tools, memory, or chat/insight pipelines
---

# AI Coach Test Plan v1
日期：2026-01-16

目标：覆盖 Context Packet + 工具层的核心路径与边界条件。

## 范围
- Coach Service: context 构建、工具调用、chat/insight 输入。
- Supabase 依赖：attempts / attempt_insights / student_snapshots / student_reports / coach_thread_messages。
- Memory 表：coach_memory_entries（若未建，工具需降级）。

## 核心场景
### 1) Context Packet
- 正常路径：linked_attempt_id → attempt + question + snapshot + recent_insights + recent_messages
- 无 attempt：仅 student 信息 + snapshot + recent 统计
- requireAttempt=true 且不存在 attempt → 抛错

### 2) Chat Flow (coach_reply)
- linked_attempt_id 有值 → prompt 中包含 attempt/question + linked_insight
- linked_attempt_id 空 → 仍包含 snapshot/reports/messages
- recent reports 为空 → accuracy/null 处理

### 3) Attempt Insight Flow
- attempt.is_correct=true → 直接跳过
- step 未选择且 job age < 2min → JobDeferredError
- step 未选择且 job age > 2min → proceed unknown

### 4) Memory Tools
- 表不存在 → memory_search/get/write 返回 disabled（不抛错）
- 表存在 → write → search 命中 → get 读取

## Corner Cases
- get_attempt_for_coach RPC 返回空/null
- student_id 缺失（attempt + student_id 都不存在）
- student_snapshots / student_reports / coach_thread_messages 为空
- memory_search query 为空（应被 schema 拒绝）
- memory_write content 过长（schema 拒绝）

## 建议执行顺序
1) 单元：context builder + prompt builder
2) 集成：coach_reply / attempt_insight（mock supabase）
3) 本地 e2e（有 supabase 时）：完整 job 处理
