# SAT Prep Monorepo

日期：2026-01-23

北极星：每个学生一个 AI 老师（错题讲解 + 追问对话 + 长期追踪）。

## 仓库结构

- `ai-coach/`：AI Coach 后端与通知服务（Node/TS）
- `web/admin-dashboard/`：运营后台（Next.js）
- `web/parent-dashboard/`：家长端（Next.js）
- `ios/`：iOS 学生端（Swift）
- `supabase/`：数据库迁移、边缘函数与配置
- `docs/`：产品与技术文档索引

## 快速入口

- 文档索引：`docs/README.md`
- AI Coach 规格：`ai-coach/docs/README.md`
- 数据库与后端：`supabase/docs/README.md`

## 根目录命令

- 首次安装：`npm install && npm run setup`
- 格式化：`npm run format`（检查：`npm run format:check`）
- 前端开发：`npm run dev`（单独：`npm run dev:admin`/`npm run dev:parent`）
- 后端开发：`npm run dev:coach` / `npm run dev:notification`

## 构建与测试（摘录）

> 详情请查看各应用目录内的 README。

- Admin Dashboard：`npm --prefix web/admin-dashboard run build` / `npm --prefix web/admin-dashboard run test`
- Parent Dashboard：`npm --prefix web/parent-dashboard run build` / `npm --prefix web/parent-dashboard run test`
- AI Coach Services：`npm --prefix ai-coach run build -w @ai-coach/shared`（详见 `AGENTS.md`）
- iOS：`swift test --package-path ios/StudentCore`
