---
summary: Refactor QuestionFeed scrolling to UIKit paging + UIKit inner scroll for deterministic gesture control.
read_when: When touching QuestionFeed paging/scrolling, nested gestures, or QuestionContentView rendering.
---

# QuestionFeed Refactor (UIKit Scroll, SwiftUI Content)

## Goal
- No edge glitches: conditional paging only when inner scroll at boundary.
- Tap reliability: no missed taps from outer pan.
- Keep SwiftUI for content + math rendering.

## Architecture
- Outer: `UICollectionView` vertical paging.
- Inner: `UIScrollView` per cell for long content.
- Content: `UIHostingController` renders `QuestionContentView` (no ScrollView).

```
UICollectionView (paging)
  └── QuestionCell
        └── UIScrollView (inner)
              └── UIHostingController.view (QuestionContentView)
```

## Files
- `StudentApp/StudentApp/Views/QuestionFeed/QuestionFeedPagingController.swift`
- `StudentApp/StudentApp/Views/QuestionFeed/QuestionCell.swift`
- `StudentApp/StudentApp/Views/QuestionFeed/QuestionContentView.swift`
- `StudentApp/StudentApp/Views/QuestionFeed/QuestionFeedContainerView.swift`
- `StudentApp/StudentApp/Views/QuestionFeedView.swift`

## Gesture Policy (Deterministic)
- Outer pan allowed only when inner at boundary:
  - upward drag → inner atBottom
  - downward drag → inner atTop
- Conditional `require(toFail:)` only when inner is scrollable.
- Outer `delaysContentTouches = false`, `canCancelContentTouches = true`.

## Boundary Math
- `isShortContent = contentHeight <= viewportHeight`
- `maxOffsetY = max(0, contentHeight - viewportHeight + insetBottom)`
- `atTop = offsetY <= -insetTop + epsilon`
- `atBottom = isShortContent || offsetY >= maxOffsetY - epsilon`
- `isScrollable = contentHeight > viewportHeight`

## State Flow
- `QuestionFeedPagingController` owns paging state.
- `feedState` / `answerStore` observed in `QuestionContentView` for UI refresh.
- Programmatic page changes call `finalizePageChange()` to sync:
  - `feedState.jump(...)`
  - `loadAnswer(...)`
  - boundary tracking for current cell

## Math Rendering Safety
- `MathTextView` uses non-interactive `WKWebView` (scroll disabled).
- UIKit scroll refactor does not affect parse/render.

## Implementation Notes
- `QuestionCell` keeps hosting controller; no teardown in reuse.
- `QuestionContentView` holds local free-response; syncs with store/state.
- `scrollViewDidEndScrollingAnimation` triggers `finalizePageChange()`.

## Minimal UI Tests (must-have)
1) Short content paging: swipe up/down pages reliably.
2) Long content: inner scroll to bottom then page; cannot page before bottom.
3) Auto-advance: select answer → next page shows correct input state (no stale).
4) Focus: text field focused → no unintended paging; commit stays on current.
5) Rapid paging: multiple fast swipes keep index + boundary correct.

## Unit Tests (lightweight)
- Boundary math: inset + short content => `atTop` and `atBottom` true.

