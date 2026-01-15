---
summary: Question Feed refactor plan with module interfaces and migration checklist
read_when: refactoring QuestionFeed, answer submission flow, or math rendering pipeline
---

# Question Feed Refactor Plan
Date: 2026-01-15
North star: stable practice flow, correct math rendering, strong performance.

## Goals
- Eliminate math rendering flicker and mis-detection of math/markup.
- Prevent answer mismatch and state desync across paging.
- Reduce coupling between view, submission, and rendering layers.
- Maintain current UI quality and interaction timing.
- Improve performance (scrolling, memory, render throughput).

## Non-goals
- Redesign of UX or visual style.
- Backend API changes or schema changes.
- Changing practice flow business rules.

## Constraints
- Target iOS 18+ only.
- New dependencies allowed.
- Keep StudentCore UI-agnostic.

## Current Pain Points (Observed)
- Math rendering flicker and unstable height during WKWebView reloads.
- Answer mismatch due to async tasks operating on stale question index.
- Single file owns paging, input, submission, perf harness, and rendering.
- Math detection uses heuristics with false positives/negatives.
- Cache keys missing width/color scheme, causing incorrect height reuse.

## Proposed Architecture (High-level)

Layers:
1) StudentCore (Foundation only)
   - MathMarkup: parsing/normalization/tokenization
   - AnswerValue already exists

2) StudentApp
   - MathRenderPipeline: render planning + cache + renderer selection
   - QuestionFeedState: UI state + deterministic transitions
   - AnswerStore: single source of truth
   - AnswerSubmissionCoordinator: submission orchestration
   - Views: thin, stateless, composed components

## Module Interfaces (Draft)

### 1) MathMarkup (StudentCore)
Foundation-only parsing and normalization. No SwiftUI.

```swift
public enum MathMarkupSegment: Equatable {
    case text(String)
    case inlineMath(String)
    case blockMath(String)
}

public struct MathMarkupDocument: Equatable {
    public let segments: [MathMarkupSegment]
    public let normalizedText: String
    public let plainText: String
    public let requiresMathRendering: Bool
    public let warnings: [MathMarkupWarning]
}

public enum MathMarkupWarning: Equatable {
    case unbalancedDelimiters
    case unknownCommand(String)
    case invalidEnvironment(String)
}

public protocol MathMarkupParsing {
    func parse(_ text: String) -> MathMarkupDocument
}

public struct MathMarkupParser: MathMarkupParsing {
    public init() {}
    public func parse(_ text: String) -> MathMarkupDocument
}
```

Responsibilities:
- Tokenize input (text vs math delimiters).
- Normalize environments (align/aligned/equation).
- Stabilize delimiters and fix common errors.
- Provide deterministic `requiresMathRendering`.
- Produce `plainText` for accessibility and fallback.

### 2) MathRenderPipeline (StudentApp)
Splits parsing from rendering; caches by layout parameters.

```swift
public struct MathRenderRequest: Hashable {
    public let text: String
    public let style: MathTextStyle
    public let width: CGFloat
    public let colorScheme: ColorScheme
    public let displayScale: CGFloat
}

public enum MathRenderPlan: Equatable {
    case plainText(AttributedString)
    case webHTML(MathHTMLPayload)
    case nativeAttributed(AttributedString)
}

public struct MathHTMLPayload: Equatable {
    public let html: String
    public let accessibilityText: String
    public let estimatedHeight: CGFloat
}

public protocol MathRenderPlanning {
    func plan(for request: MathRenderRequest) -> MathRenderPlan
}

public final class MathRenderPlanner: MathRenderPlanning {
    public init(parser: MathMarkupParsing)
    public func plan(for request: MathRenderRequest) -> MathRenderPlan
}
```

Optional renderer interfaces (dependency-injection friendly):

```swift
public protocol MathRenderer {
    func render(_ payload: MathHTMLPayload, into webView: WKWebView) async throws -> CGFloat
}

public protocol MathWebViewPoolProviding {
    func acquire() -> WKWebView
    func release(_ webView: WKWebView)
}
```

Renderer selection strategy:
- If no math segments: `plainText`.
- If math segments and native renderer available (SwiftMath): `nativeAttributed`.
- Otherwise: `webHTML` via WKWebView (KaTeX).
- On failure: fallback to `plainText`.

Cache keys include: text + style + width + colorScheme + displayScale.

### 3) QuestionFeedState (StudentApp)
Single source of truth for paging + input + UI flags.

```swift
@MainActor
public final class QuestionFeedState: ObservableObject {
    @Published public private(set) var currentIndex: Int
    @Published public private(set) var inputState: QuestionInputState
    @Published public private(set) var autoAdvanceState: AutoAdvanceState

    public init(initialIndex: Int = 0)

    public func jump(to index: Int, total: Int)
    public func advance(total: Int)
    public func retreat()
    public func resetInput(for questionId: String, from store: AnswerStore)
    public func applySelection(_ selection: AnswerSelection, questionId: String)
    public func markSubmitted(questionId: String)
}

public struct QuestionInputState: Equatable {
    public var selectedOption: String?
    public var freeResponse: String
    public var isFocused: Bool
    public var showFeedback: Bool
}

public enum AnswerSelection: Equatable {
    case option(String)
    case freeResponse(String)
}

public struct AutoAdvanceState: Equatable {
    public var isScheduled: Bool
    public var scheduledForQuestionId: String?
}
```

Rules:
- All transitions are driven by questionId, not index, to prevent mismatch.
- Any async task must verify `scheduledForQuestionId` before advancing.

### 4) AnswerStore (StudentApp)
Answers are not stored in the view.

```swift
public protocol AnswerStore: AnyObject {
    subscript(questionId: String) -> AnswerValue? { get set }
    func clear(questionId: String)
    func allAnswers() -> [String: AnswerValue]
}

public final class InMemoryAnswerStore: AnswerStore {
    public init(initial: [String: AnswerValue] = [:])
}
```

### 5) AnswerSubmissionCoordinator (StudentApp)
Wraps PracticeFlowViewModel submission; enforces ordering and dedupe.

```swift
public protocol AnswerSubmitting {
    func submitAnswer(question: Question, answer: String, allowCoach: Bool) async throws -> SubmitAttemptResult
}

@MainActor
public final class AnswerSubmissionCoordinator {
    public init(submitter: AnswerSubmitting)

    public func submit(
        question: Question,
        answer: String,
        questionId: String,
        onSuccess: @escaping (SubmitAttemptResult) -> Void,
        onFailure: @escaping (Error) -> Void
    )

    public func cancelAll()
}
```

Notes:
- Coordinator holds per-question task map, cancels stale tasks on paging.
- Pending answers still handled in PracticeFlowViewModel.

### 6) QuestionFeedView Composition (StudentApp)
View becomes thin, only consumes state and actions.

```swift
struct QuestionFeedView: View {
    @StateObject var state: QuestionFeedState
    let store: AnswerStore
    let submission: AnswerSubmissionCoordinator
    let session: PracticeSession
    let onBack: () -> Void
    let onShowOverview: () -> Void
}
```

Component extraction:
- `QuestionFeedHeaderView`
- `QuestionBodyView`
- `OptionsListView`
- `FreeResponseInputView`
- `OverviewTriggerCardView`

## Dependency Choice (Math Rendering)
Preferred: SwiftMath (native attributed rendering) + WebKit fallback.
- Benefits: less flicker, no WebView for simple math, lower memory.
- Fallback: KaTeX via WKWebView for complex or unsupported features.

### SwiftMath Integration Details (Draft)

API surface (StudentApp):

```swift
public enum MathRenderFailure: Error, Equatable {
    case unsupported
    case empty
    case renderFailed(String)
}

public protocol MathNativeRendering {
    func renderAttributed(
        latex: String,
        style: MathTextStyle,
        maxWidth: CGFloat
    ) throws -> AttributedString
}

public final class SwiftMathRenderer: MathNativeRendering {
    public init() {}
    public func renderAttributed(
        latex: String,
        style: MathTextStyle,
        maxWidth: CGFloat
    ) throws -> AttributedString
}
```

Planner decision table:
- No math segments -> `plainText`.
- Math segments, all inline, size < 600 chars, no unknown commands -> SwiftMath.
- Block math or unknown commands -> WebKit (KaTeX).
- SwiftMath throws -> WebKit.
- WebKit fails or times out -> `plainText` fallback.

Caching strategy:
- Two-level cache: `planCache` (MathRenderPlan) + `heightCache` (final height).
- Key: `textHash|styleKey|width|colorScheme|displayScale`.
- `styleKey`: fontSize|weight|lineHeight|lineSpacing|textAlign.
- `width` bucketed to 1pt (ceil to nearest 1.0) to avoid tiny layout churn.
- `displayScale` included to prevent mismatched raster metrics.

WebKit pooling:
- `MathWebViewPool` size 2-3; reuse WKWebView instances.
- Render queue limited to 2 concurrent tasks to prevent memory spikes.

Instrumentation:
- Log counters: swiftmath_success, swiftmath_fail, webkit_fallback, webkit_fail.
- Track avg render time per renderer.

## Migration Checklist (Step-by-step)

Phase 0: Guardrails
- Add temporary feature flags: `mathPipelineV2Enabled`.
- Add instrumentation logs for render failures and auto-advance mismatch.

Phase 1: MathMarkup (StudentCore)
- Add new parsing module with tests.
- Keep existing MathTextView untouched.

Phase 2: MathRenderPipeline (StudentApp)
- Add planner + cache + renderer interfaces.
- Implement KaTeX WebKit renderer using current HTML builder.
- Add SwiftMath renderer behind feature flag.

Phase 3: MathTextView v2
- Replace detection/preprocess with MathMarkup + pipeline.
- Keep fallback to plain text on failure.

Phase 4: State Refactor
- Introduce QuestionFeedState + AnswerStore.
- Move input logic out of `QuestionFeedView` into state.
- Ensure all async tasks check questionId.

Phase 5: Submission Coordinator
- Wrap PracticeFlowViewModel as `AnswerSubmitting`.
- Cancel stale submission tasks on paging.
- Guarantee single in-flight submission per questionId.

Phase 6: View Decomposition
- Split into subviews.
- Remove perf harness from production path (debug only).

Phase 7: Cleanup
- Delete old heuristics (`MathTextPreprocessor`, `MathContentDetector`).
- Remove hash-based ID usage; use stable ids (`question.id`, `segment index`).

## Test Plan
- Unit: MathMarkup parser edge cases (unbalanced delimiters, text-only blocks).
- Unit: MathRenderPlanner (plan selection, cache keys).
- Unit: QuestionFeedState transitions (advance, jump, auto-advance).
- Unit: AnswerSubmissionCoordinator dedupe and cancellation.
- Smoke: Practice flow paging + answer sync + math render on device.

## Rollout
- Ship with `mathPipelineV2Enabled` off by default.
- Enable for internal users only, then staged rollout.
- Compare flicker rate + render failures before full enable.
