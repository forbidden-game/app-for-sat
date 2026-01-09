# iOS Product & UX Review (StudentApp)

日期：2026-01-09  
范围：`ios/StudentApp` + `ios/StudentCore`（学生端 MVP）

## 1. 本次 review 的目标

- 从“学生刷题产品”的闭环视角审视当前 iOS 端功能与 UI 体验。
- 盘点：已实现的主链路、当前短板、下一步开发方向与优先级。
- 输出：可执行的 backlog（含验收标准），便于迭代落地与对齐。

## 2. 已跑通的真实 UI 链路（基于 Simulator 实测）

> 说明：本次 review 既看代码也跑了 UI。由于题库数量/题型会随数据变化，以下描述聚焦交互形态与状态流转。

- Auth：未登录进入 `AuthView`（支持 Sign In / Create Account；错误文案目前来自服务端原始 message）
- Home：登录后进入题库入口网格 `QuestionBankSelectionView`
- Practice：进入练习流 `PracticeFlowView`
  - `QuestionFeedView`：逐题刷题（纵向分页）
  - `SessionOverviewView`：题号网格 + Submit
  - `SessionResultView`：分数圆环 + 题目列表（对/错）
  - `QuestionDetailView`：单题解析（选项高亮 + Explanation）
- Side panel：右上角入口打开侧边栏，当前仅提供 Sign Out + 版本号

## 3. 当前产品实现盘点（“做到了什么”）

### 3.1 已具备的产品能力（MVP）

- 基础账号体系：注册/登录/登出（Supabase Auth）
- 题库入口（question banks）：
  - 可配置 title/subtitle/icon
  - 可按 sort_order 排序展示
- 练习 session：
  - 从题库启动 session（RPC：`start_practice_session`）
  - 单题作答上报（Edge Function：`submit_attempt`）
  - session 结果聚合（RPC：`get_session_result`）
- 结果查看：
  - session 总分展示（correct/total）
  - 单题对错列表
  - 进入单题详情查看正确答案/用户答案/解析

### 3.2 工程侧正向点

- 视觉系统已抽象为 token（`AppTheme` / `AppMetrics`），整体一致性不错
- 视图结构清晰：`Auth -> Bank Selection -> Practice Flow` 的状态机直观
- 结果页与详情页信息架构基础成立（可扩展）

## 4. 主要不足与风险（按“对产品闭环 + 未来维护成本”的优先级）

下面的不足不是“现在就必须全做”，而是用于确定下一步方向与里程碑。

### P0 · 会直接影响迭代效率/稳定性的短板

#### P0-1：题目分页实现会放大性能/可测试性/可访问性问题

- 现象：
  - `PagingScrollView` 为一个 session 的所有题目一次性创建 `UIHostingController` 页面（`pageCount = questions + 1`）。
  - 当题量较大（例如 50 题）时，页面数量直接线性增长。
  - 在 UI 自动化/可访问性层面，会出现同 label 元素大量重复（例如多个 `Back`），导致定位困难。
- 影响：
  - 内存与首屏渲染成本不可控；长题干/图片题会进一步放大。
  - VoiceOver 与 UI Automation 可能出现混乱（同 label 多实例、隐藏视图可达）。
  - 后续引入题目资产（图片/图表）后风险更高。
- 建议方向（两条路径二选一）：
  1) 保留“纵向 swipe 翻页”的交互，但做页面虚拟化（仅保留 current/prev/next 三页，或用 `UICollectionView` 做 paging）。
  2) 退一步改成“单题视图 + 明确 Next/Previous 按钮”，用 `ScrollView` 只承载当前题内容（实现成本低，确定性强）。
- 验收标准（示例）：
  - 50 题 session 首次进入练习页不卡顿（无明显掉帧/冻结）。
  - VoiceOver 下 `Back`/题号/选项可唯一定位且读序正确。
  - UI 自动化可以稳定完成“随机答 5 题→overview→submit→result→detail”。

#### P0-2：环境配置硬编码（Supabase URL/anon key）影响安全与多环境迭代

- 现象：`SupabaseConfig` 直接硬编码 url/key。
- 影响：
  - 不利于 dev/staging/prod 分离；也不利于本地/离线 UI review。
  - 安全与密钥轮换成本上升。
- 建议方向：
  - 将配置移到 `Info.plist` / `.xcconfig` / build settings，并提供 Debug-only 覆盖方式。
  - 引入 demo mode（Debug-only）：不依赖线上 Supabase 也能跑通关键 UI（用于评审、截图、回归）。
- 验收标准：
  - Debug 可以切换到 mock 数据源，不登录也能跑通主流程。
  - Release 不包含测试环境配置与调试开关。

### P1 · 会显著影响“刷题体验”和“学习闭环”的短板

#### P1-1：作答反馈语义可能误导

- 现象：选择选项后的“绿色成功反馈”与真实对错无关（目前像是“答对了”）。
- 影响：
  - 学生会把“绿色”解读为正确，破坏信任。
  - 产品语义不一致：对错到底是“即时反馈”还是“提交后反馈”？
- 建议方向：
  - 将即时反馈改为“已记录/已提交”的中性状态（例如 accent/selected），不要使用 success/danger 语义色。
  - 若要即时对错，需要在客户端持有正确答案或服务端实时返回对错并显式展示（这又会影响题目泄露策略）。
- 验收标准：
  - UI 中 success/danger 颜色只用于真实对错结果，不用于“点击确认”动画。

#### P1-2：SessionOverview 的提交策略与未答提示不足

- 现象：
  - 未答题允许直接 Submit；未答会被计为错，但缺少确认/提示。
  - overview 仅区分 answered/unanswered（缺少计数、剩余提示、回到未答的引导）。
- 建议方向：
  - Submit 前弹出确认：显示“未答题数/将被计为错/是否继续”。
  - overview 增加“未答筛选/跳转第一个未答”的快捷动作。
- 验收标准：
  - 未答 > 0 时 Submit 需要二次确认，且文案清晰。

#### P1-3：数值题缺少明确 CTA（用户不一定知道要按键盘 Done）

- 现象：numeric 输入依赖键盘提交，没有明显“Next/Submit answer”按钮。
- 建议方向：
  - 固定底部 CTA（Next / Submit Answer），键盘弹起时保持可达。
  - 或在输入框右侧提供“提交/下一题”按钮。
- 验收标准：
  - 不依赖键盘 Done，用户也能完成作答并前进。

### P2 · 下一阶段产品化能力（形成留存的学习闭环）

#### P2-1：缺少“学习闭环”与长期进度

- 现状：一次 session 的结果可看，但没有：
  - 历史 session 列表/统计趋势
  - 错题集（重练/收藏/按标签复盘）
  - 学习目标/连续打卡（streak）
  - 题型/知识点维度的正确率归因
- 建议方向（最小闭环）：
  - SessionHistory + WrongSet + Basic Progress（三件套）。
  - 优先做“能告诉学生下一步做什么”的导向（例如“今天最弱的 2 个 topic”）。

#### P2-2：题目资产/富文本渲染未覆盖

- schema 已有 `question_assets`，但学生端 UI 未展示。
- SAT 题库大概率需要图片/图表/排版（甚至数学公式）。
- 建议方向：
  - 先支持图片 + 简单富文本（Markdown 子集或自定义段落结构）。
  - 需要提前设计 `Question.stem` 的渲染协议（避免后续推倒重来）。

## 5. 推荐的下一步里程碑（Slow is Fast）

> 目标：每个里程碑都能交付“可测、可验证”的用户价值，同时降低后续迭代成本。

### Milestone 0（工程与评审基础设施，1–3 天）

- 多环境配置改造（最小：Debug 支持本地/测试环境；Release 走生产）
- Debug-only demo mode（mock banks / mock session / mock result），用于 UI review 与自动化测试

### Milestone 1（练习体验硬核打磨，1–2 周）

- 题目分页重构（虚拟化或单题模式二选一）
- numeric 题明确 CTA
- Submit 前未答确认 + overview 快捷引导
- 作答反馈语义纠正（success/danger 仅用于真实结果）

### Milestone 2（最小学习闭环，2–4 周）

- SessionHistory（最近 N 次、按题库维度聚合）
- WrongSet（错题重练/收藏）
- 基础进度面板（正确率趋势 + weak topics）

## 6. 需要你确认/输入的信息（为了减少返工）

> 你说“两个关键点不关键”我理解为：短期先按工程与体验优先推进，不在“即时对错 vs 提交后对错”上卡太久。

为了让 backlog 更落地，我只需要你补充两类信息：

1) 近期目标更偏哪一类？
   - A) 留存导向：日常练习/错题/进度闭环
   - B) 考试导向：计时/模拟考/强约束
2) 题目内容形态预计最早需要支持到什么程度？
   - A) 纯文本 + MCQ/numeric（短期）
   - B) 图片/图表（近期）
   - C) 复杂排版/公式（中期）

## 7. 参考代码入口（便于后续落地）

- App state & routing：`ios/StudentApp/StudentApp/ContentView.swift`
- Auth：`ios/StudentApp/StudentApp/Views/AuthView.swift` / `ios/StudentCore/Sources/StudentCore/AuthService.swift`
- Banks：`ios/StudentApp/StudentApp/Views/QuestionBankSelectionView.swift` / `ios/StudentCore/Sources/StudentCore/SupabasePracticeService.swift`
- Practice flow：`ios/StudentApp/StudentApp/Views/PracticeFlowView.swift`
- Paging：`ios/StudentApp/StudentApp/Views/PagingScrollView.swift`
- Result & detail：`ios/StudentApp/StudentApp/Views/SessionResultView.swift` / `ios/StudentApp/StudentApp/Views/QuestionDetailView.swift`
- UI tokens：`ios/StudentApp/StudentApp/Views/AppTheme.swift` / `ios/UI_DESIGN.md`

