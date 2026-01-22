---
summary: QuestionFeed vertical paging decision rule (authoritative).
read_when: Changing swipe/paging, gesture arbitration, or feed UX.
---

# QuestionFeed Paging (Very Important)

## Why this matters
- Incorrect direction mapping caused fast/slow swipe reversals.
- Velocity/translation signs often disagree due to inertia and bounce.

## Current rule (authoritative)
1) Use UIKit-provided `targetContentOffset` to compute `proposedIndex`.
2) Only accept `proposedIndex` if movement crosses thresholds.
3) Otherwise keep `currentIndex`.

## Implementation
- Target computation lives in `QuestionFeedPagingTargetIndex.verticalTargetIndex`.
- Caller passes:
  - `currentIndex`
  - `maxIndex`
  - `proposedIndex` (from `targetContentOffset`)
  - `translationY`, `velocityY`, `pageHeight`

## Thresholds
- Translation: `abs(translationY) > pageHeight * 0.1`
- Velocity: `abs(velocityY) > 0.3`

## Rationale
- `targetContentOffset` reflects UIKit paging resolution and avoids sign conflicts.
- Thresholds prevent accidental page changes on tiny drags.

## Do not change casually
- Any change to direction rules should be validated with:
  - slow drag + release
  - fast flick
  - mixed diagonal swipe
