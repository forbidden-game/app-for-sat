# AI Coach Runbook

日期：2026-01-23

## 范围

- AI Coach workers：`coach-service` 与 `notification-sender`
- 默认环境变量文件：`/etc/app-for-sat/ai-coach.env`
- 通知服务环境变量文件：`/etc/ai-coach/notification-sender.env`

## 服务与健康检查

- systemd 服务（默认）：`ai-coach-chat-worker.service`、`ai-coach-insight-worker.service`、`ai-coach-grammar-worker.service`
- 额外服务（如部署通知）：`ai-coach-notification-sender.service`
- 健康检查：`/usr/local/bin/ai-coach-healthcheck.sh`（timer: `ai-coach-healthcheck.timer`）

## 常用命令

- 查看服务状态：`systemctl status <service>`
- 查看日志：`journalctl -u <service> -f`
- 手动健康检查：`/usr/local/bin/ai-coach-healthcheck.sh`

## 部署路径定位

- 查看 service 配置：`systemctl cat ai-coach-insight-worker.service`
- 关注字段：`WorkingDirectory`、`ExecStart`（通常包含 repo 路径）
- 如果 service 里没有路径，查看进程：`ps aux | rg "ai-coach/coach-service"`

## English Grammar Worker

- 目的：只处理 `english_grammar_analysis`
- 注意：分工模式下应保持 `ai-coach-worker.service` 处于 disabled/stopped，避免与 chat/insight/grammar 竞争任务导致重复 claim。
- service 示例（`/etc/systemd/system/ai-coach-grammar-worker.service`）：

```ini
[Unit]
Description=AI Coach Grammar Worker
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/apps/app-for-sat/ai-coach/coach-service
EnvironmentFile=/etc/app-for-sat/ai-coach.env
Environment=AI_COACH_WORKER_ID=alibaba_vps_grammar
Environment=AI_COACH_JOB_KINDS=english_grammar_analysis
Environment=AI_COACH_ENABLE_SCHEDULER=false
ExecStart=/usr/bin/node /root/apps/app-for-sat/ai-coach/coach-service/dist/index.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

## 常见问题与处理

### 1) 任务堆积或卡住

- 现象：日志出现 claim 失败、stale job 或队列积压
- 排查：确认 `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` 有效；检查 Supabase 状态
- 处理：重启对应 worker；必要时在 Supabase 查看 `ai_jobs` 状态
- 英语语法分析：`select id, status, updated_at from ai_jobs where kind = 'english_grammar_analysis' order by updated_at desc limit 20;`

### 2) 模型调用失败

- 现象：日志出现 `missing_minimax_api_key` 或 provider error
- 排查：检查 `MINIMAX_API_KEY`/`OPENAI_API_KEY` 等配置
- 处理：更新 `/etc/app-for-sat/ai-coach.env`，重启服务

### 3) 英语语法分析无结果

- 现象：iOS 进入语法分析后长期停留在 queued/running
- 排查：
  - 检查 `english_grammar_analyses` 表是否有 `status=error`
  - 查看 `ai_jobs` 中 `english_grammar_analysis` 是否被 claim
  - 查看 worker 日志是否有 `english_grammar_invalid_json`
- 处理：修正 prompt 或模型输出后重试；可手动删掉对应 analysis 行触发重新生成

### 3) 通知发送失败

- 现象：notification sender 日志报 APNS 错误
- 排查：检查 APNS 证书/密钥与 `NOTIFICATION_SENDER_MODE`
- 处理：确认 APNS 配置后重启 `ai-coach-notification-sender.service`

## 观测与告警

- 日志默认会脱敏：如需关闭，设置 `LOG_REDACT=false`
- 若启用 Sentry，需配置 `SENTRY_DSN`/`SENTRY_ENVIRONMENT`/`APP_RELEASE` 并设置告警规则
