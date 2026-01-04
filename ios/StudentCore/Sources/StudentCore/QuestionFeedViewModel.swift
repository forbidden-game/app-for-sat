import Combine

public final class QuestionFeedViewModel: ObservableObject {
    public let session: PracticeSession
    @Published public private(set) var currentIndex: Int = 0

    public init(session: PracticeSession) {
        self.session = session
    }

    public func advance() {
        guard currentIndex + 1 < session.questions.count else { return }
        currentIndex += 1
    }

    public func retreat() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
    }

    public func jump(to index: Int) {
        guard index >= 0 && index < session.questions.count else { return }
        currentIndex = index
    }
}
