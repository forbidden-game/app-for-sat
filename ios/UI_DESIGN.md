# iOS UI Design System (StudentApp)
日期：2026-01-14

## Goals
- Maintain a calm, focused study experience with clear hierarchy and low visual noise.
- Keep cards and controls consistent across screens.
- Use semantic tokens for color and metrics to avoid one-off styling.
- Keep AI teacher surfaces (wrong-answer coach + followup dialog) clear and conversational.

## Color Tokens (AppTheme)
Use `AppTheme` colors only. Do not hardcode colors in views.

- Background: `backgroundPrimary`, `backgroundSecondary`, `backgroundGradient`
- Surfaces: `surface`, `surfaceRaised`, `surfacePressed`
- Text: `textPrimary`, `textSecondary`, `textMuted`, `textOnAccent`
- Accent: `accent`, `accentStrong`
- Status: `statusSuccess`, `statusWarning`, `statusDanger`
- Dividers: `divider`, `dividerStrong`
- Shadows: `shadowSoft`, `shadowStrong`

## Metrics (AppMetrics)
Centralize all spacing, corner radii, and sizing in `AppMetrics`.

| Token | Value | Usage |
| --- | --- | --- |
| `cardCornerRadius` | 20 | Large cards (question stem, panels) |
| `cardPadding` | 18 | Card internal padding |
| `cardShadowRadius` | 10 | Card elevation |
| `cardShadowY` | 4 | Card elevation offset |
| `rowCornerRadius` | 16 | Rows, list items, buttons |
| `rowPaddingVertical` | 10 | Row vertical padding |
| `rowPaddingHorizontal` | 16 | Row horizontal padding |
| `rowShadowRadius` | 8 | Row elevation |
| `rowShadowY` | 4 | Row elevation offset |
| `badgeSize` | 32 | Option badge size |
| `badgeSizeSmall` | 28 | Compact badge size |
| `gridButtonSize` | 48 | Grid button size |
| `fieldPaddingVertical` | 12 | Text field vertical padding |
| `fieldPaddingHorizontal` | 16 | Text field horizontal padding |
| `primaryButtonPaddingVertical` | 14 | Primary CTA padding |
| `headerSpacing` | 8 | Header vertical spacing |
| `sectionSpacing` | 16 | Section vertical spacing |
| `sectionSpacingLarge` | 24 | Large section spacing |
| `rowSpacing` | 10 | Row stack spacing |
| `pageBottomPadding` | 20 | Bottom padding for pages |
| `screenHorizontalPadding` | 20 | Screen horizontal padding |
| `screenTopPadding` | 16 | Screen top padding |
| `screenBottomPadding` | 24 | Screen bottom padding |
| `screenBottomPaddingLarge` | 32 | Screen bottom padding (large) |
| `gridSpacing` | 12 | Grid spacing (compact) |
| `gridSpacingWide` | 20 | Grid spacing (wide) |
| `gridItemMinimum` | 56 | Minimum grid item width |
| `panelCornerRadius` | 28 | Side panel corner radius |
| `panelShadowRadius` | 22 | Side panel shadow radius |
| `panelShadowY` | 12 | Side panel shadow offset |

## Typography
Use system fonts with clear hierarchy and limited variants.

- Screen title: `.title3.weight(.semibold)`
- Section title: `.headline`
- Body text: `.body` with `lineSpacing(2)`
- Support text: `.subheadline` or `.callout`
- Badges: `.subheadline.weight(.semibold)`

## Components

### Card
- Use for question stem and major content blocks.
- Apply with `.appSurface` and `AppMetrics.cardCornerRadius`.

Example:
```swift
Text(content)
    .font(.title3.weight(.semibold))
    .lineSpacing(4)
    .padding(AppMetrics.cardPadding)
    .appSurface(
        fill: AppTheme.surface,
        stroke: AppTheme.divider,
        cornerRadius: AppMetrics.cardCornerRadius,
        shadowRadius: AppMetrics.cardShadowRadius,
        shadowY: AppMetrics.cardShadowY
    )
```

### Row / Option
- Use for selectable options and list rows.
- Keep padding and corner radius consistent.

Example:
```swift
HStack {
    // content
}
.padding(.vertical, AppMetrics.rowPaddingVertical)
.padding(.horizontal, AppMetrics.rowPaddingHorizontal)
.appSurface(
    fill: AppTheme.surfaceRaised,
    stroke: AppTheme.dividerStrong,
    showShadow: false
)
```

### Primary Button
- Full-width CTA with `accentStrong` background.

Example:
```swift
Text("Continue")
    .font(.headline)
    .foregroundStyle(AppTheme.textOnAccent)
    .frame(maxWidth: .infinity)
    .padding(.vertical, AppMetrics.primaryButtonPaddingVertical)
    .background(AppTheme.accentStrong)
    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
```

### Badge
- Circular label using `badgeSize` or `badgeSizeSmall`.

Example:
```swift
Text("A")
    .font(.subheadline.weight(.semibold))
    .frame(width: AppMetrics.badgeSize, height: AppMetrics.badgeSize)
    .background(AppTheme.surfaceRaised)
    .clipShape(Circle())
```

## Layout Rules
- Prefer `AppMetrics.sectionSpacing` between major blocks.
- Avoid stacking heavy borders and shadows on the same element.
- Only elevate elements that are interactive or primary content.

## States
- Selected: use `accent` or `statusSuccess` for stroke, `surfacePressed` for fill.
- Disabled: reduce contrast with `textMuted` and avoid shadows.

## Accessibility
- Maintain high contrast for `textPrimary` and `textOnAccent`.
- Support Dynamic Type by using system fonts and avoiding hardcoded sizes.

## Implementation Notes
- Use `.appCard(...)` for standard cards and `.appSurface(...)` for rows and custom surfaces.
- Do not introduce new hardcoded spacing or corner radii without updating `AppMetrics`.
