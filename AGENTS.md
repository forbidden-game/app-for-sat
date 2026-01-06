# AGENTS.md — SAT Prep Student App

## Project Structure

```
ios/
├── StudentApp/           # SwiftUI iOS application (Xcode project)
│   ├── StudentApp.xcodeproj
│   └── StudentApp/
│       ├── Views/        # SwiftUI views
│       ├── ViewModels/   # App-level view models
│       └── StudentAppApp.swift
└── StudentCore/          # Swift Package (business logic, models, services)
    ├── Package.swift
    ├── Sources/StudentCore/
    └── Tests/StudentCoreTests/
```

**Architecture**: The app uses a local Swift Package (`StudentCore`) for core logic, consumed by the Xcode project via local package reference.

---

## Build & Test Commands

### StudentCore (Swift Package)

```bash
# Build the package
swift build --package-path ios/StudentCore

# Run all tests
swift test --package-path ios/StudentCore

# Run a single test file
swift test --package-path ios/StudentCore --filter ModelsTests

# Run a single test method
swift test --package-path ios/StudentCore --filter QuestionFeedViewModelTests/testAdvanceMovesIndex

# Clean build artifacts
swift package clean --package-path ios/StudentCore
```

### StudentApp (Xcode Project)

```bash
# Build for simulator
xcodebuild -project ios/StudentApp/StudentApp.xcodeproj \
  -scheme StudentApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests (if test target exists)
xcodebuild -project ios/StudentApp/StudentApp.xcodeproj \
  -scheme StudentApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

**Note**: The xcodebuild MCP tools are available for simulator/device builds. Prefer those for interactive development.

---

## Code Style Guidelines

### Swift Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Types (struct, class, enum, protocol) | UpperCamelCase | `QuestionFeedViewModel`, `PracticeSession` |
| Properties, methods, variables | lowerCamelCase | `currentIndex`, `fetchSession()` |
| Constants | lowerCamelCase | `let commitThreshold: CGFloat = 120` |
| Enum cases | lowerCamelCase | `case previous`, `case next` |
| Protocols | UpperCamelCase + noun/adjective | `APIClient`, `Codable` |

### File Organization

- **Views**: One view per file, file name matches struct name (`QuestionFeedView.swift`)
- **ViewModels**: Suffix with `ViewModel` (`QuestionFeedViewModel.swift`)
- **Models**: Plain structs in `Models.swift` or grouped by domain
- **Services**: Suffix with `Service` (`SupabaseService.swift`)

### Import Order

1. Foundation / standard library
2. System frameworks (SwiftUI, Combine, UIKit)
3. Third-party packages (Supabase)
4. Local modules (StudentCore)

```swift
import Foundation
import SwiftUI
import Combine
import Supabase
import StudentCore
```

### Type Design

**Public API for Package Types**:
```swift
public struct Question: Codable, Equatable {
    public let id: String
    public let questionType: String
    // ... properties

    public init(id: String, questionType: String, ...) {
        self.id = id
        self.questionType = questionType
        // ...
    }
}
```

**ViewModels**: Use `@Published` for observable state, `private(set)` for controlled mutation:
```swift
public final class QuestionFeedViewModel: ObservableObject {
    @Published public private(set) var currentIndex: Int = 0

    public func advance() {
        guard currentIndex + 1 < session.questions.count else { return }
        currentIndex += 1
    }
}
```

### SwiftUI Patterns

**View Composition**: Extract reusable pieces as private methods:
```swift
struct QuestionFeedView: View {
    var body: some View {
        VStack {
            header(progress: progress, ...)
            questionCard(text: question.stem)
            // ...
        }
    }

    private func header(...) -> some View { ... }
    private func questionCard(text: String) -> some View { ... }
}
```

**Theme Constants**: Use `AppTheme` enum for colors and styling:
```swift
enum AppTheme {
    static let backgroundTop = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.14)
    // ...
}
```

### Error Handling

- Use `async throws` for fallible async operations
- Protocol-based dependency injection for testability:
```swift
public protocol APIClient {
    func fetchSession() async throws -> PracticeSession
}

public final class PracticeService {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }
}
```

### Testing Patterns

- Test file naming: `<Module>Tests.swift` (e.g., `ModelsTests.swift`)
- Use `@testable import StudentCore` for internal access
- Provide mock implementations for protocols:
```swift
public final class MockAPIClient: APIClient {
    public var fetchSessionCalled = false

    public func fetchSession() async throws -> PracticeSession {
        fetchSessionCalled = true
        return PracticeSession(id: "S1", questions: [])
    }
}
```

---

## Language & Documentation

- **Code, comments, identifiers, commit messages**: English only
- **Explanations in conversation**: Chinese is acceptable (per user preference)
- Comments: Explain "why", not "what" — only when intent is non-obvious

---

## Dependencies

- **Swift 6.2** (swift-tools-version: 6.2)
- **iOS 15.0+** / **macOS 10.15+**
- **supabase-swift** (2.0.0+) — Backend integration

---

## Key Modules

| Module | Purpose |
|--------|---------|
| `Models.swift` | Core data types: `Question`, `QuestionOption`, `AnswerKey` |
| `API.swift` | `APIClient` protocol, `PracticeSession`, `PracticeService` |
| `QuestionFeedViewModel.swift` | Navigation state for question feed |
| `SupabaseService.swift` | Supabase client singleton |
| `AuthService.swift` | Authentication logic |
| `QuestionBank.swift` | Question bank management |

---

## Git Conventions

- Commit only files you modified; ignore unrelated workspace changes
- No force push, no history rewriting unless explicitly requested
- Use `gh` CLI for GitHub operations

---

## Quick Reference

```bash
# Fast package test cycle
swift test --package-path ios/StudentCore --filter <TestName>

# Check for build errors
swift build --package-path ios/StudentCore 2>&1 | head -50

# Format check (if SwiftFormat configured)
swiftformat ios/StudentCore --lint
```
