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
}
