# AI Coach（每个学生一个长期老师）— 规格草案

目标：为每个学生提供一个“全科 AI 老师（单一总线程）”，它能在学生错题时做**短、步骤化、问答式纠错**，并长期追踪学生的学习状态；当遇到新错题时，会先检索该学生历史上“步骤相似”的错误（procedure + step），命中则进行重点讲解与对比。

本目录文档用于指导后续实现（iOS 优先、SAT Math 先行）。

## 核心决策（已确认）
- 学科：先做 `SAT Math`。
- 讲解风格：严格步骤训练（短、问答、纠错），避免长篇大论；学生可继续追问。
- 相似错误判定：先用 `procedure_id + error_step_index`（高召回/稳定），`error_mode` 作为细分与加权证据；后续再逐步提高其权重。
- iOS 交互：错题页新增“我卡在第几步”的点选，**默认必填**，但提供“`unknown`（不确定）”选项。
- 对话：一人一个总线程（全科老师），允许跨题对话。
- 题库无标准解析：由 AI 生成“标准步骤（steps）”与讲解，且要求有证据链（引用题干条件/选项陷阱/学生选择与正确选择差异）。
- taxonomy 自增长：procedures 由 AI 自己扩展，但必须有“先检索再创建、可合并/别名、版本化 steps”三道护栏。

## 产出形态（面向产品）
- 错题页：
  - 展示“本题所属套路（procedure）+ 通用步骤 steps（3–7步）”。
  - 学生选择卡点步（或 unknown）。
  - 返回短讲解 + 1–2 个追问（引导学生回答，从而修正诊断）。
- 老师对话页：
  - 同一线程可跨题。
  - 回答前按需检索：学生长期快照 + 相似错误证据。

## 系统形态（工程）
- `Supabase`：存储 attempts / questions / tags（已存在），并新增 procedures、attempt_insights、student_snapshot、coach_thread_messages 等（见 `data-model.md`）。
- `Node/TS Coach Service`（推荐）：使用 `pi-mono` 的 `@mariozechner/pi-agent-core` + `@mariozechner/pi-ai` 实现“StudentCoachAgent”，并通过工具调用强制流程：先检索 → 再讲解 → 再写回 DB。
  - 注：Supabase Edge Functions 是 Deno 环境，不建议直接跑 `pi-agent-core`（Node 生态）。

## 文档索引
- `ai-coach/docs/data-model.md`：建议新增表/字段（MVP）。
- `ai-coach/docs/flows.md`：错题处理流、对话流。
- `ai-coach/docs/agent-tools.md`：工具调用契约（Tool schemas）。
- `ai-coach/docs/error-modes.md`：SAT Math 初始 `error_mode_enum`（带 Unknown）。
- `ai-coach/docs/procedures.md`：procedure/steps 自增长规则与模板。

## 下一步（实现顺序建议）
1. 先落 DB 表 + 最小 API：写入 insight、查询相似错误、读 student snapshot。
2. 做 Coach Service（pi-agent-core）：实现错题讲解与对话。
3. iOS 端新增“步骤点选 + 老师对话入口”。
4. 加入压缩与评估：thread_summary、prompt_version、成本与效果指标。
