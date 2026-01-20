---
summary: SAT Prep overall product, architecture, and core flows
read_when: changing core flows, submission, or backend data consistency
---

# SAT Prep Project Overview
日期：2026-01-15

最后更新：2026-01-15

## 核心北极星
每个学生都有一个专属 AI 老师：当下错题讲解、可反复追问的对话、长期学习追踪与个性化指导。iOS/Web/后端的所有功能都围绕这位老师服务。

## 项目定位
面向 SAT 备考的学习系统，核心是“每个学生一个 AI 老师”。其他模块为其提供数据与运营支撑：
- 学生端：刷题与即时反馈，承接 AI 老师的错题讲解与追问对话。
- 家长端：可视化长期学习趋势与薄弱点，反映 AI 老师的长期跟踪结果。
- 后端：统一记录练习与对话数据，支撑 AI 老师的长期记忆与个性化。

## 用户与角色
- Student：进行练习、提交答案、查看讲解与个人统计。
- Parent：查看绑定学生的学习趋势与薄弱点。
- Admin：维护题库与运营配置（题库、题目、规则）。

## 产品形态
- iOS Student App：SwiftUI UI + `StudentCore` Swift Package 作为模型与 API 层。
- Parent Web Dashboard：Next.js，面向家长的进度与分析展示。
- Admin Web Dashboard：Next.js，面向运营与题库管理。
- Supabase Backend：Postgres + RLS + Edge Functions + Storage。

## 架构概览
1. 客户端（iOS/Web）通过 Supabase Auth 登录。
2. 题库与练习数据存储在 Supabase Postgres。
3. 核心业务通过 RPC 与 Edge Functions 完成：
   - 练习 session 下发（不含答案）。
   - 作答提交与评分（支持 `client_submission_id` 幂等）。
   - AI 讲解生成与缓存。
4. 家长端通过聚合 RPC 获取统计视图。

## 核心业务流程（MVP）
1. **开始练习**
   - 调用 `start_practice_session` RPC。
   - 返回 session 与题目列表（不包含答案）。
2. **提交作答**
   - 客户端先记录到本地“待同步队列”，再异步提交。
   - 调用 Edge Function `submit_attempt`（携带 `client_submission_id` 幂等）。
   - 服务端评分并写入/更新 `attempts`，`sessions.correct_count` 按唯一正确题目重算。
3. **查看讲解**
   - 调用 Edge Function `generate_explanation`（当前为 stub，后续接入 LLM）。
   - 缓存结果写入 `ai_explanations`。
4. **错题追问与老师对话**
   - 错题选择卡点步骤，写入 `attempt_insights`（AI 老师短讲解 + 追问）。
   - 学生可进入“全科老师”总线程进行多轮对话。
5. **家长仪表盘**
   - 调用 `get_parent_dashboard` RPC，一次性返回聚合数据。

## 数据模型要点（摘要）
- `profiles`：用户身份与角色。
- `questions` + `question_options` + `question_assets`：题库内容。
- `question_banks` + `question_bank_questions`：题库入口与编排规则。
- `sessions` + `session_questions` + `attempts`：练习 session 与作答记录。
- `ai_explanations`：AI 讲解缓存。

详细字段与关系见 `supabase/docs/schema.md`。

## 代码结构
```text
.
  docs/
  ios/
    StudentApp/
    StudentCore/
  supabase/
    docs/
    functions/
    migrations/
    seed/
  web/
    admin-dashboard/
    parent-dashboard/
    docs/
```

## 关键实现位置
- iOS 学生端：`ios/StudentApp` + `ios/StudentCore`。
- 家长端 Web：`web/parent-dashboard`。
- 管理端 Web：`web/admin-dashboard`。
- Supabase Schema：`supabase/migrations` + `supabase/docs/schema.md`。
- Edge Functions：`supabase/functions/submit_attempt`、`supabase/functions/generate_explanation`。
- AI Coach：`ai-coach/`（docs + worker）。

## 文档索引（建议先读）
- 文档入口与规范：`docs/README.md`
- AI Coach 规格入口：`ai-coach/docs/README.md`
- Supabase Schema：`supabase/docs/schema.md`
- Web 说明：`web/docs/README.md`

## 任务拆分建议（面向多 Agent）
- **iOS Agent**：UI/交互、练习流、离线缓存、StudentCore API 设计。
- **Backend Agent**：Supabase schema/RLS、RPC、Edge Functions、数据一致性。
- **Web Parent Agent**：Dashboard 视图、聚合数据展示、交互与权限边界。
- **Web Admin Agent**：题库管理、运营配置与数据校验。
