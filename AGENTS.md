# Agent Runbook

日期：2026-01-23

本文件用于自动化代理快速完成环境搭建、构建与测试。

## 全局依赖

- Node.js 20+
- npm
- Supabase CLI
- Swift 6（iOS）

## 应用清单

- `ai-coach/coach-service`：AI Coach 后端 worker
- `ai-coach/notification-sender`：推送通知 worker
- `web/admin-dashboard`：运营后台（Next.js）
- `web/parent-dashboard`：家长端（Next.js）
- `ios/StudentApp` + `ios/StudentCore`：iOS App 与共享 Core

## 本地开发

### Web 应用

```bash
cd web/admin-dashboard
npm install
npm run dev
```

```bash
cd web/parent-dashboard
npm install
npm run dev
```

### AI Coach 服务

```bash
cd ai-coach
npm install --workspaces --include-workspace-root
npm run build -w @ai-coach/shared
```

## 环境变量

- `ai-coach/coach-service/.env.example`
- `ai-coach/notification-sender/.env.example`
- `web/admin-dashboard/.env.local`（见 README）
- `web/parent-dashboard/.env.local`（见 README）

## 测试

### Web

```bash
cd web/admin-dashboard
npm run lint
npm run test
```

```bash
cd web/parent-dashboard
npm run lint
npm run test
```

### AI Coach

```bash
supabase start
supabase db reset

cd ai-coach/coach-service
npm test

cd ../notification-sender
npm test
```

### iOS

```bash
swift test --package-path ios/StudentCore
```

## 构建

```bash
cd web/admin-dashboard
npm run build

cd ../parent-dashboard
npm run build

cd ../../ai-coach
npm run build -w @ai-coach/shared
npm run build -w ai-coach-service
npm run build -w ai-coach-notification-sender
```
