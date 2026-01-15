---
summary: Docs index and conventions
read_when: adding or updating docs, changing doc conventions
---

# SAT Prep Docs Index
日期：2026-01-15

北极星：每个学生一个 AI 老师（错题讲解 + 追问对话 + 长期追踪）。

## 文档目录结构
```
docs/
  README.md               # 本文档索引与规范
  project-overview.md     # 产品与系统总览
  ai-coach-flow.md        # AI Coach 后端流程草案
  ai-coach/README.md      # AI Coach 入口（指向 ai-coach/docs）
  ios/ios-app-overview.md # iOS 学生端概览
  ios/question-feed-refactor-plan.md # Question Feed refactor plan
```

跨目录文档入口：
```
ai-coach/docs/            # AI Coach 规格与实现细节
supabase/docs/            # 数据库与后端 schema
web/docs/                 # Web 总览
web/parent-dashboard/docs # 家长端规格
```

## 文档格式规范（统一）
每个文档建议包含以下顺序：
1) `# 标题`
2) `日期：YYYY-MM-DD`
3) `北极星：...`（若该文档是功能/模块级）
4) 目的 / 范围（Purpose / Scope）
5) 关键流程 / 数据 / API
6) 参考实现位置 / 依赖

命名约定：
- 面向产品与系统的文档放在 `docs/`
- AI Coach 细节放在 `ai-coach/docs/`
- iOS / Web / Supabase 分别放在各自目录
- 不维护“下一步计划”文档；只记录**当前真实状态与已确认决策**
