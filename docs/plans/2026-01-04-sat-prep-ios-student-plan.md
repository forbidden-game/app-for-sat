# SAT Prep iOS Student App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the iOS student MVP app with a swipe-based question feed, answer submission stub, and session summary.

**Architecture:** SwiftUI app backed by a small Swift Package (`StudentCore`) for models, API client, and view models. UI stays thin and state-driven.

**Tech Stack:** SwiftUI, Swift Package Manager, Supabase Swift SDK (wired later).

---

### Task 1: Scaffold iOS app shell

**Files:**
- Create: `ios/StudentApp/` (Xcode project)

**Step 1: Create the Xcode project**

Manual: Open Xcode → Create New Project → iOS App
- Product Name: `StudentApp`
- Interface: SwiftUI
- Language: Swift
- Bundle Identifier: `com.yourorg.satprep.student`
- Location: `ios/StudentApp`

**Step 2: Verify project builds**

Run (from project folder): `xcodebuild -scheme StudentApp -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add ios/StudentApp
git commit -m "chore: scaffold iOS student app"
```

---

### Task 2: Create StudentCore Swift package with models

**Files:**
- Create: `ios/StudentCore/Package.swift`
- Create: `ios/StudentCore/Sources/StudentCore/Models.swift`
- Create: `ios/StudentCore/Tests/StudentCoreTests/ModelsTests.swift`

**Step 1: Create the package skeleton**

Run: `mkdir -p ios/StudentCore && cd ios/StudentCore && swift package init --type library --name StudentCore`
Expected: `Package.swift` and `Sources/StudentCore` created.

**Step 2: Write failing tests**

```swift
// ios/StudentCore/Tests/StudentCoreTests/ModelsTests.swift
import XCTest
@testable import StudentCore

final class ModelsTests: XCTestCase {
  func testQuestionDecodeMCQ() throws {
    let json = #"{"id":"Q1","questionType":"mcq","stem":"2+2?","options":[{"label":"A","content":"3"},{"label":"B","content":"4"}],"answerKey":{"correct":"B"}}"#
    let data = json.data(using: .utf8)!
    let q = try JSONDecoder().decode(Question.self, from: data)
    XCTAssertEqual(q.options?.count, 2)
    XCTAssertEqual(q.answerKey.correctString, "B")
  }
}
```

**Step 3: Run test to verify it fails**

Run: `cd ios/StudentCore && swift test`
Expected: FAIL (Question type not defined)

**Step 4: Write minimal implementation**

```swift
// ios/StudentCore/Sources/StudentCore/Models.swift
import Foundation

public struct Question: Codable, Equatable {
  public let id: String
  public let questionType: String
  public let stem: String
  public let options: [QuestionOption]?
  public let answerKey: AnswerKey
}

public struct QuestionOption: Codable, Equatable {
  public let label: String
  public let content: String
}

public struct AnswerKey: Codable, Equatable {
  public let correctString: String?
  public let correctNumber: Double?

  public init(correct: String) { correctString = correct; correctNumber = nil }
  public init(correct: Double) { correctNumber = correct; correctString = nil }

  enum CodingKeys: String, CodingKey { case correct }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let s = try? container.decode(String.self, forKey: .correct) {
      correctString = s; correctNumber = nil
    } else if let n = try? container.decode(Double.self, forKey: .correct) {
      correctNumber = n; correctString = nil
    } else {
      correctString = nil; correctNumber = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let s = correctString { try container.encode(s, forKey: .correct) }
    if let n = correctNumber { try container.encode(n, forKey: .correct) }
  }
}
```

**Step 5: Run test to verify it passes**

Run: `cd ios/StudentCore && swift test`
Expected: PASS

**Step 6: Commit**

```bash
git add ios/StudentCore
git commit -m "feat: add StudentCore models"
```

---

### Task 3: Add API client interface and mocks

**Files:**
- Create: `ios/StudentCore/Sources/StudentCore/API.swift`
- Create: `ios/StudentCore/Tests/StudentCoreTests/APITests.swift`

**Step 1: Write failing tests**

```swift
// ios/StudentCore/Tests/StudentCoreTests/APITests.swift
import XCTest
@testable import StudentCore

final class APITests: XCTestCase {
  func testFetchSessionUsesClient() async throws {
    let client = MockAPIClient()
    let service = PracticeService(client: client)
    _ = try await service.fetchSession()
    XCTAssertEqual(client.fetchSessionCalled, true)
  }
}
```

**Step 2: Run test to verify it fails**

Run: `cd ios/StudentCore && swift test`
Expected: FAIL (PracticeService not found)

**Step 3: Write minimal implementation**

```swift
// ios/StudentCore/Sources/StudentCore/API.swift
import Foundation

public protocol APIClient {
  func fetchSession() async throws -> PracticeSession
}

public struct PracticeSession: Codable, Equatable {
  public let id: String
  public let questions: [Question]
}

public final class PracticeService {
  private let client: APIClient
  public init(client: APIClient) { self.client = client }
  public func fetchSession() async throws -> PracticeSession { try await client.fetchSession() }
}

public final class MockAPIClient: APIClient {
  public var fetchSessionCalled = false
  public init() {}
  public func fetchSession() async throws -> PracticeSession {
    fetchSessionCalled = true
    return PracticeSession(id: "S1", questions: [])
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd ios/StudentCore && swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add ios/StudentCore/Sources/StudentCore/API.swift ios/StudentCore/Tests/StudentCoreTests/APITests.swift
git commit -m "feat: add API client abstraction"
```

---

### Task 4: Add QuestionFeedViewModel

**Files:**
- Create: `ios/StudentCore/Sources/StudentCore/QuestionFeedViewModel.swift`
- Create: `ios/StudentCore/Tests/StudentCoreTests/QuestionFeedViewModelTests.swift`

**Step 1: Write failing tests**

```swift
// ios/StudentCore/Tests/StudentCoreTests/QuestionFeedViewModelTests.swift
import XCTest
@testable import StudentCore

final class QuestionFeedViewModelTests: XCTestCase {
  func testAdvanceMovesIndex() async throws {
    let session = PracticeSession(id: "S1", questions: [
      Question(id: "Q1", questionType: "mcq", stem: "A?", options: nil, answerKey: AnswerKey(correct: "A")),
      Question(id: "Q2", questionType: "mcq", stem: "B?", options: nil, answerKey: AnswerKey(correct: "B"))
    ])
    let vm = QuestionFeedViewModel(session: session)
    XCTAssertEqual(vm.currentIndex, 0)
    vm.advance()
    XCTAssertEqual(vm.currentIndex, 1)
  }
}
```

**Step 2: Run test to verify it fails**

Run: `cd ios/StudentCore && swift test`
Expected: FAIL (QuestionFeedViewModel not found)

**Step 3: Write minimal implementation**

```swift
// ios/StudentCore/Sources/StudentCore/QuestionFeedViewModel.swift
import Foundation

public final class QuestionFeedViewModel: ObservableObject {
  public let session: PracticeSession
  @Published public private(set) var currentIndex: Int = 0

  public init(session: PracticeSession) { self.session = session }

  public func advance() {
    guard currentIndex + 1 < session.questions.count else { return }
    currentIndex += 1
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd ios/StudentCore && swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add ios/StudentCore/Sources/StudentCore/QuestionFeedViewModel.swift ios/StudentCore/Tests/StudentCoreTests/QuestionFeedViewModelTests.swift
git commit -m "feat: add question feed view model"
```

---

### Task 5: Wire StudentCore into iOS app and render feed

**Files:**
- Modify: `ios/StudentApp/StudentApp.xcodeproj`
- Create: `ios/StudentApp/StudentApp/Views/QuestionFeedView.swift`
- Modify: `ios/StudentApp/StudentApp/ContentView.swift`

**Step 1: Add StudentCore package dependency**

Manual (Xcode): File → Add Packages → Add Local Package → `ios/StudentCore`

**Step 2: Implement minimal QuestionFeedView**

```swift
// ios/StudentApp/StudentApp/Views/QuestionFeedView.swift
import SwiftUI
import StudentCore

struct QuestionFeedView: View {
  @StateObject var vm: QuestionFeedViewModel

  var body: some View {
    let question = vm.session.questions[vm.currentIndex]
    VStack(alignment: .leading, spacing: 16) {
      Text(question.stem).font(.title2)
      Button("Next") { vm.advance() }
    }
    .padding()
  }
}
```

**Step 3: Replace ContentView to show feed**

```swift
import SwiftUI
import StudentCore

struct ContentView: View {
  var body: some View {
    let sample = PracticeSession(id: "S1", questions: [
      Question(id: "Q1", questionType: "mcq", stem: "2+2?", options: nil, answerKey: AnswerKey(correct: "B"))
    ])
    QuestionFeedView(vm: QuestionFeedViewModel(session: sample))
  }
}
```

**Step 4: Manual smoke test**

Run app on simulator, verify question renders and Next button is visible.

**Step 5: Commit**

```bash
git add ios/StudentApp/StudentApp/Views/QuestionFeedView.swift ios/StudentApp/StudentApp/ContentView.swift ios/StudentApp/StudentApp.xcodeproj
git commit -m "feat: add question feed view"
```

---

### Task 6: Add session summary screen

**Files:**
- Create: `ios/StudentApp/StudentApp/Views/SessionSummaryView.swift`
- Modify: `ios/StudentApp/StudentApp/ContentView.swift`

**Step 1: Implement summary view**

```swift
import SwiftUI

struct SessionSummaryView: View {
  let total: Int
  let correct: Int

  var body: some View {
    VStack(spacing: 12) {
      Text("Session Complete").font(.title)
      Text("Score: \(correct)/\(total)")
    }
    .padding()
  }
}
```

**Step 2: Manual smoke test**

Swap ContentView to show summary view temporarily and verify it renders.

**Step 3: Commit**

```bash
git add ios/StudentApp/StudentApp/Views/SessionSummaryView.swift ios/StudentApp/StudentApp/ContentView.swift
git commit -m "feat: add session summary view"
```

---

## Notes
- Supabase auth + data fetching will be wired after backend endpoints are live.
- Next plan should add answer submission, AI explanation access, and parent link handling.

---

Plan complete and saved to `docs/plans/2026-01-04-sat-prep-ios-student-plan.md`.
