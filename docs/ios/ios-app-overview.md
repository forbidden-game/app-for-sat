---
summary: iOS Student App flow, screens, and submission behavior
read_when: updating iOS practice flow, submission, or Coach UX
---

# iOS Student App Overview
日期：2026-01-15

## 概览
当前 iOS 端是一个面向学生的 SAT 练习 App，核心目标是让每个学生拥有一个专属 AI 老师（错题讲解、可反复追问、长期追踪）。应用采用 SwiftUI + StudentCore（SPM 包）分层，UI 负责展示与交互，业务与数据访问集中在 `StudentCore`。

## 业务流程
1. 启动应用
2. 未登录：进入登录/注册
3. 登录成功：拉取题库列表
4. 选择题库：创建练习 Session
5. 进入练习流：题目上下滑动切换，提交答案
6. 错题触发 AI 老师讲解与追问入口（Coach）
7. 打开 Session Overview：检查题目完成情况并提交
8. 退出练习：回到题库选择

## 页面说明
### 1) 登录/注册（AuthView）
- 输入 Email 与 Password
- 支持 Sign In / Create Account
- 异步请求期间显示加载态
- 错误提示以内联方式展示

### 2) 题库选择（QuestionBankSelectionView）
- 顶部显示日期与当天日号
- 以网格卡片展示题库
- 选择题库后进入练习 Session
- 加载中会遮罩并显示 Progress

### 3) 练习题目流（QuestionFeedView）
- 顶部显示返回按钮、题目进度与进度条
- 支持两类输入：
  - 选择题：选项按钮
  - 填空题：输入框提交
- 自动前进策略：
  - 选择题点击后自动前进（默认 220ms，可配置 `autoAdvanceDelayMs`）
  - 填空题输入后自动提交并前进（同上延迟）
- 题目切换：上下滑动切换题目（外层分页）
- 内容区滚动：题干 + 选项/输入在固定内容区内滚动，只有当前题可滚动
- 手势归属：内容区未到顶/底时仅内层滚动，到顶/底后才允许外层翻页
- 作答可修改：未提交前已作答题目仍可修改，新的答案会立即再次提交并覆盖
- 错题处理：展示 CoachStepSheet（选择卡点步）→ 拉取 AI 讲解
- 提交策略：本地先记，再异步提交；失败会进入“待同步队列”

### 4) Session Overview（SessionOverviewView）
- 网格展示题号，已作答题号高亮
- 可点选题号回到题目
- 提交按钮用于提交剩余答案
- 若存在待同步题目，显示“未同步 X 题，连网后自动提交”

### 5) 侧边面板（SidePanelView）
- 在“非练习中”状态显示入口按钮
- 展示用户缩写、邮箱与版本信息
- 支持 Sign Out

### 6) AI 老师对话（CoachChatView）
- 全科老师“王校长”总线程，支持跨题追问
- 支持实时流式回复
- 输入栏支持：拍照（点击相机）/相册（长按相机）/语音录制
- 语音录制：点击麦克风开始/停止，生成语音消息气泡并可回放
- 语音消息：波形长度随时长变化，播放时显示进度与当前时间
- 提示语：根据学生画像动态轮播（弱项/节奏/习惯提醒）

## 数据与服务交互
- 拉取题库：查询 `question_banks`
- 创建 Session：RPC `start_practice_session`
- 提交答案：Function `submit_attempt`（支持 `client_submission_id` 幂等）
- 错题步骤选择：Function `set_attempt_step`
- AI 讲解与追问：读取 `attempt_insights`
- 全科老师对话：Function `coach_chat` + Realtime `coach_thread_messages`
- 登录与注册：Supabase Auth

## 页面截图
### 题库选择
![题库选择页面](assets/ios-home.png)

### 练习题目流
![练习题目页面](assets/ios-question-feed.png)

### 侧边面板
![侧边面板](assets/ios-side-panel.png)

## 已实现但未接通
- `SessionSummaryView`：代码已实现，但当前流程未跳转到该页面。

## 参考实现位置
- `ios/StudentApp/StudentApp/ContentView.swift`
- `ios/StudentApp/StudentApp/Views/QuestionBankSelectionView.swift`
- `ios/StudentApp/StudentApp/Views/QuestionFeedView.swift`
- `ios/StudentApp/StudentApp/Views/SessionOverviewView.swift`
- `ios/StudentApp/StudentApp/Views/SidePanelView.swift`
- `ios/StudentApp/StudentApp/ViewModels/AppViewModel.swift`
- `ios/StudentApp/StudentApp/ViewModels/PracticeFlowViewModel.swift`
- `ios/StudentCore/Sources/StudentCore/SupabasePracticeService.swift`
