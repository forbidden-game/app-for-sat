# 家长端 Web 仪表盘设计（MVP）

Date: 2026-01-05

## 目标
- 家长进入后 10 秒内获取孩子学习状态（时长、错误率、排名）。
- 通过趋势与强弱项判断近期变化与风险点。
- 指标口径可扩展，避免未来新增功能时重构数据模型。

## 设计原则
- 先定义语义（指标与口径），再落到 UI 与数据库。
- 可解释性优先：所有指标都能追溯到明确的计算规则。
- 低样本保护：避免用很少题数给出强结论。

## MVP 范围
- 总览卡片：学习时长、错误率、横向排名。
- 趋势图：近 5 次测验的准确率与排名变化。
- 强弱项：按题型/标签统计正确率（显示题数）。

## 关键假设（当前版本）
- 横向比较群体：全部用户。
- “测验”= `session`。
- 学习时长允许挂机（不对单题时间上限进行裁剪）。

## 页面信息架构（MVP）
- 头部：学生选择（多孩场景预留）。
- 总览区：3 个 KPI 卡片（时长、错误率、排名）。
- 趋势区：近 5 次测验折线图（准确率 + 排名）。
- 强弱项区：按题型/标签正确率分布（条形图/列表）。

## 指标定义与口径

### 1) 学习时长（Study Time）
- 口径：`sum(attempt.duration_ms)`
- 时间窗口：默认近 7 天（可扩展为 30/90 天）。
- 显示：分钟（`duration_ms / 60000`，保留 1 位小数）。
- 说明：允许挂机会导致该指标偏高，后续可引入“有效时长”。

### 2) 错误率（Error Rate）
- 口径：`incorrect / (correct + incorrect)`
- `attempted = correct + incorrect`，不包含 `skipped`。
- 时间窗口：默认近 7 天。

### 3) 横向排名（Rank Percentile）
- 展示形式：百分位（越大越好）。
- 口径：以近 7 天准确率为基准的排名。
- 规则：仅统计 `attempts_7d >= 20` 的学生。
- 计算：`percentile = rank(accuracy_7d) / total_eligible`。
- 说明：排名基于“全部用户”群体，后续支持分组（年级/地区/班级）。

### 4) 近 5 次测验趋势（Trend）
- 数据源：最近 5 个 `session`（按 `created_at` 倒序）。
- 每次测验展示：`session_accuracy` 与 `rank_percentile`。
- MVP 版本排名策略：使用“当前窗口”的排名近似，不保留历史快照。

### 5) 强弱项（Strengths & Weaknesses）
- 维度：题型/标签（`tag`）。
- 指标：`tag_accuracy = correct / (correct + incorrect)`。
- 筛选：`attempts_per_tag >= 10` 才进入统计。
- 展示：Top 3 强项 + Bottom 3 弱项；附题数。

## 数据契约（前端所需字段）

```json
{
  "student": {
    "id": "uuid",
    "name": "string",
    "grade": "string"
  },
  "overview": {
    "window_days": 7,
    "practice_minutes": 123.4,
    "accuracy": 0.86,
    "error_rate": 0.14,
    "rank_percentile": 0.78,
    "attempts": 42
  },
  "trend": [
    {
      "session_id": "uuid",
      "created_at": "2026-01-05T10:00:00Z",
      "accuracy": 0.9,
      "rank_percentile": 0.8,
      "attempts": 20,
      "duration_minutes": 35.0
    }
  ],
  "topics": [
    {
      "tag_id": "uuid",
      "tag_name": "algebra",
      "accuracy": 0.72,
      "attempts": 18
    }
  ]
}
```

## 数据来源与聚合策略
- 源表：`sessions`, `attempts`, `question_tags`, `tags`, `parent_student_links`, `profiles`。
- 聚合方式（建议）：
  - `student_overview_7d` 视图或物化表（按学生聚合）。
  - `student_trend_last_5_sessions` 视图或 RPC。
  - `student_topic_stats_7d` 视图或物化表。
- 刷新策略：
  - MVP 可在查询时动态聚合。
  - 后续在 `session` 完成时增量更新聚合表。

## 空态与边界条件
- 题数不足：显示“数据不足”与最低题数提示。
- 无测验：趋势区为空态文案 + 引导开始练习。
- 未绑定学生：提示绑定流程。

## 可扩展点
- 排名分组：按年级/地区/学校/班级。
- 时间窗口切换：7/30/90 天。
- 更细分的强弱项：按知识点层级或难度。
- 历史排名快照：避免趋势图使用“当前排名”近似。

## 待定项
- 排名基准人群的正式定义与过滤规则。
- “有效学习时长”的口径与作弊/挂机识别。
- session 分类（practice/quiz）的产品规则。
