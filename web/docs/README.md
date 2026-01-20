---
summary: Web dashboards overview and local setup
read_when: working on web dashboards, updating admin or parent UI, running web apps
---

# Web 文档
日期：2026-01-15

## 目录结构
```text
web/
  admin-dashboard/
  parent-dashboard/
  docs/
```

## 应用说明
`parent-dashboard` 面向家长，提供学习进度与学生详情等功能，核心是呈现 AI 老师的长期追踪成果。  
`admin-dashboard` 面向运维/业务管理者，提供题库、用户与运营概览，保障 AI 老师的数据与运营供给；包含 AI Config 与 Audit Log。

## 环境变量
`parent-dashboard`：
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

`admin-dashboard`：
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`（仅服务端使用）

## 本地运行
Parent:
```bash
cd web/parent-dashboard
npm run dev
```

Admin:
```bash
cd web/admin-dashboard
npm run dev
```

## 近期改动
- 管理端从 `parent-dashboard` 中拆分，迁移为独立的 `admin-dashboard`。
- 管理端路由保持 `/admin`，并使用 server-side service role 访问后端。
- 管理端新增题库管理（question_banks）的增删改查页面。
- 管理端新增 AI Config（ai_prompt_configs）、OpenRouter key 配置（ai_provider_keys）与 AI Logs（ai_agent_logs）。
- 管理端 UI/UX 统一更新（排版、表格、表单、面板与 AI Logs 视图样式）。
- 管理端品牌文案更新为 “Backside of Meng’s Dream”。
