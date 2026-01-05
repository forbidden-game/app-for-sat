# iOS Student App Overview

## 概览
当前 iOS 端是一个面向学生的 SAT 练习 App，核心目标是让学生选择题库并完成一组练习题。应用采用 SwiftUI + StudentCore（SPM 包）分层，UI 负责展示与交互，业务与数据访问集中在 `StudentCore`。

## 业务流程
1. 启动应用
2. 未登录：进入登录/注册
3. 登录成功：拉取题库列表
4. 选择题库：创建练习 Session
5. 进入练习流：题目上下滑动切换，提交答案
6. 打开 Session Overview：检查题目完成情况并提交
7. 退出练习：回到题库选择

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
  - 选择题点击后自动前进
  - 填空题输入后 0.6s 自动提交并前进
- 题目切换：上下滑动切换题目

### 4) Session Overview（SessionOverviewView）
- 网格展示题号，已作答题号高亮
- 可点选题号回到题目
- 提交按钮用于提交剩余答案

### 5) 侧边面板（SidePanelView）
- 在“非练习中”状态显示入口按钮
- 展示用户缩写、邮箱与版本信息
- 支持 Sign Out

## 数据与服务交互
- 拉取题库：查询 `question_banks`
- 创建 Session：RPC `start_practice_session`
- 提交答案：Function `submit_attempt`
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
