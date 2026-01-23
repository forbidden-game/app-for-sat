# iOS UI Design System (StudentApp)

日期：2026-01-19

## Goals

- 统一 Dark-only 视觉风格，贴合 chess.com iOS 的色调与层级。
- 通过语义 token + 组件抽象，避免页面级硬编码。
- 明确 TopBar/TabBar/CTA/练习流的视觉与交互规范。
- 练习场景保持沉浸，弱化噪声、强调主行动线。

## Color Tokens (AppTheme)

Use `AppTheme` colors only. Do not hardcode colors in views.

- Chrome: `chromeBackground`, `chromeDivider`
- Background: `backgroundPrimary`, `backgroundSecondary`, `backgroundGradient`
- Surfaces: `surface`, `surfaceRaised`, `surfacePressed`
- Text: `textPrimary`, `textSecondary`, `textMuted`, `textOnAccent`
- Accent: `accent`, `accentStrong`, `accentSoft`
- CTA Gradient: `ctaGreenFillTop`, `ctaGreenFillBottom`, `ctaGreenStrokeTop`, `ctaGreenStrokeBottom`, `ctaFillGradient`, `ctaStrokeGradient`
- Board Tones: `boardLight`, `boardDark`
- Status: `statusSuccess`, `statusWarning`, `statusDanger`
- Dividers: `divider`, `dividerStrong`
- Shadows: `shadowSoft`, `shadowStrong`

Notes:

- 全局以 Dark-only 为基准，light/dark 均使用同一套值保证一致性。
- CTA 按钮必须使用渐变填充+渐变描边（与 iOS 参考图一致）。

## Metrics (AppMetrics)

Centralize all spacing, corner radii, and sizing in `AppMetrics`.

| Token                          | Value | Usage                |
| ------------------------------ | ----- | -------------------- |
| `cardCornerRadius`             | 16    | 卡片/大面板          |
| `cardPadding`                  | 18    | 卡片内边距           |
| `cardShadowRadius`             | 4     | 卡片阴影             |
| `cardShadowY`                  | 2     | 卡片阴影偏移         |
| `rowCornerRadius`              | 14    | 行/列表项/按钮       |
| `rowPaddingVertical`           | 10    | 行垂直内边距         |
| `rowPaddingHorizontal`         | 16    | 行水平内边距         |
| `rowShadowRadius`              | 4     | 行阴影               |
| `rowShadowY`                   | 2     | 行阴影偏移           |
| `badgeSize`                    | 32    | 选项徽章             |
| `badgeSizeSmall`               | 28    | 紧凑徽章             |
| `gridButtonSize`               | 48    | 网格按钮             |
| `fieldPaddingVertical`         | 12    | 文本输入垂直内边距   |
| `fieldPaddingHorizontal`       | 16    | 文本输入水平内边距   |
| `primaryButtonPaddingVertical` | 14    | CTA 内边距           |
| `headerSpacing`                | 8     | Header 间距          |
| `sectionSpacing`               | 16    | 区块间距             |
| `sectionSpacingLarge`          | 24    | 大区块间距           |
| `rowSpacing`                   | 10    | 行间距               |
| `pageBottomPadding`            | 20    | 页面底部内边距       |
| `screenHorizontalPadding`      | 20    | 页面水平内边距       |
| `screenTopPadding`             | 16    | 页面顶部内边距       |
| `screenBottomPadding`          | 24    | 页面底部内边距       |
| `screenBottomPaddingLarge`     | 32    | 页面底部内边距（大） |
| `gridSpacing`                  | 12    | 网格间距             |
| `gridSpacingWide`              | 20    | 网格间距（宽）       |
| `gridItemMinimum`              | 56    | 最小网格尺寸         |
| `panelCornerRadius`            | 24    | 面板圆角             |
| `panelShadowRadius`            | 12    | 面板阴影             |
| `panelShadowY`                 | 6     | 面板阴影偏移         |
| `topBarHeight`                 | 52    | TopBar 高度          |
| `tabBarHeight`                 | 64    | TabBar 高度          |

## Typography

Use system fonts with clear hierarchy and limited variants.

- TopBar 标题: `.headline.weight(.semibold)`
- Section title: `.headline`
- Body text: `.body`
- Support text: `.subheadline` / `.callout`
- Badges: `.subheadline.weight(.semibold)`

## Components

### AppShell

- 结构：TopBar + Tab content + TabBar。
- Tabs: `首页 / 王校长 / 复盘`，社交入口仅在 TopBar 右侧。

### AppTopBar

- 左：头像/个人入口。
- 中：当前 tab 标题（可选 subtitle）。
- 右：社交圈按钮（打开好友列表 sheet）。

### AppTabBar

- 仅 3 个 tab；选中使用 `accentStrong`，未选中使用 `textMuted`。

### PracticeTopBar

- 练习会话内专用：仅保留 `返回 / 进度 / 总览`。
- 背景 `chromeBackground`，底部分隔线 `chromeDivider`。

### Primary CTA Button

- 使用 `PrimaryCTAButton`（渐变填充 + 渐变描边）。

Example:

```swift
PrimaryCTAButton(title: "练习", isLoading: isLoading, isDisabled: disabled) {
    // action
}
```

### Card / Row

- 使用 `.appSurface(...)` 统一填充/描边/阴影。
- 首页题库卡片采用“列表卡片”风格（不再使用网格）。

### Friends Sheet

- 通过 TopBar 右侧按钮打开。
- 顶部 `ModalTopBar`，右侧提供分享链接。
- 点击头像进入好友主页，点击行主体进入聊天。

## Practice Flow Rules

- 背景：`PracticeBackgroundView`（暗色渐变 + 极淡棋盘纹理）。
- 选项选中态：使用棋盘两色（`boardLight` / `boardDark`），替换纯绿色高亮。
- 避免强阴影，强调描边与层级。

## States

- Selected: 练习选项使用 `boardDark` 为描边/徽章主色。
- Disabled: `textMuted` + 降低对比，不使用强阴影。

## Accessibility

- 保持 `textPrimary` 与深色背景对比度。
- CTA 文案使用更大字号/加粗，必要时可加轻微阴影提升可读性。

## Implementation Notes

- 不要在 View 中硬编码颜色；全部使用 `AppTheme`。
- 不要引入新的 spacing/圆角值；全部使用 `AppMetrics`。
- 首页卡片点击直接进入题库练习；底部 CTA 走推荐题库 RPC。
- 练习会话时隐藏 TabBar，仅保留 PracticeTopBar。
