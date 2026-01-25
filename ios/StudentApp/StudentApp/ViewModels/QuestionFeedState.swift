import Combine
import Foundation
import StudentCore

@MainActor
final class QuestionFeedState: ObservableObject {
    @Published private(set) var currentIndex: Int
    @Published private(set) var inputState: QuestionInputState
    @Published private(set) var autoAdvanceState: AutoAdvanceState

    /// Start time for the overall practice session ("time bank").
    private(set) var sessionStartedAt: Date

    private var stemPageByQuestionId: [String: Int] = [:]
    private var stemPageCountByQuestionId: [String: Int] = [:]
    private var stemSwipeHintSeenQuestionIds: Set<String> = []
    private var draftFreeResponseByQuestionId: [String: String] = [:]

    init(initialIndex: Int = 0) {
        currentIndex = initialIndex
        inputState = QuestionInputState()
        autoAdvanceState = AutoAdvanceState()
        sessionStartedAt = .now
    }

    func jump(to index: Int, total: Int) {
        guard total > 0 else { return }
        let clamped = max(0, min(index, total - 1))
        currentIndex = clamped
    }

    func advance(total: Int) {
        guard currentIndex + 1 < total else { return }
        currentIndex += 1
    }

    func retreat() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
    }

    func resetInput(for questionId: String, from store: AnswerStore, isMultipleChoice: Bool) {
        var next = QuestionInputState()
        if !isMultipleChoice {
            if let answer = store[questionId] {
                next.freeResponse = answer.displayString
            } else if let draft = draftFreeResponseByQuestionId[questionId] {
                next.freeResponse = draft
            }
        }
        inputState = next
        autoAdvanceState = AutoAdvanceState()
    }

    func applySelection(_ selection: AnswerSelection) {
        var next = inputState
        switch selection {
        case .option:
            next.freeResponse = ""
        case .freeResponse(let value):
            next.freeResponse = value
        }
        next.isFocused = false
        next.showFeedback = false
        inputState = next
    }

    func updateFreeResponse(_ value: String, questionId: String) {
        var next = inputState
        next.freeResponse = value
        inputState = next

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draftFreeResponseByQuestionId.removeValue(forKey: questionId)
        } else {
            draftFreeResponseByQuestionId[questionId] = value
        }
    }

    func clearDraft(for questionId: String) {
        draftFreeResponseByQuestionId.removeValue(forKey: questionId)
    }

    func setFocus(_ focused: Bool) {
        var next = inputState
        next.isFocused = focused
        inputState = next
    }

    func setFeedbackVisible(_ visible: Bool) {
        var next = inputState
        next.showFeedback = visible
        inputState = next
    }

    func scheduleAutoAdvance(for questionId: String) {
        autoAdvanceState = AutoAdvanceState(isScheduled: true, scheduledForQuestionId: questionId)
    }

    func clearAutoAdvance() {
        autoAdvanceState = AutoAdvanceState()
    }

    func stemPage(for questionId: String) -> Int {
        stemPageByQuestionId[questionId] ?? 0
    }

    func setStemPage(_ page: Int, for questionId: String) {
        let clamped = max(0, page)
        if stemPageByQuestionId[questionId] != clamped {
            objectWillChange.send()
            stemPageByQuestionId[questionId] = clamped
        }
    }

    func stemPageCount(for questionId: String) -> Int {
        stemPageCountByQuestionId[questionId] ?? 1
    }

    func setStemPageCount(_ count: Int, for questionId: String) {
        let clamped = max(1, count)
        if stemPageCountByQuestionId[questionId] != clamped {
            objectWillChange.send()
            stemPageCountByQuestionId[questionId] = clamped
        }
    }

    func hasSeenStemSwipeHint(for questionId: String) -> Bool {
        stemSwipeHintSeenQuestionIds.contains(questionId)
    }

    func markSeenStemSwipeHint(for questionId: String) {
        if !stemSwipeHintSeenQuestionIds.contains(questionId) {
            objectWillChange.send()
            stemSwipeHintSeenQuestionIds.insert(questionId)
        }
    }
}

struct QuestionInputState: Equatable {
    var freeResponse: String = ""
    var isFocused: Bool = false
    var showFeedback: Bool = false
}

enum AnswerSelection: Equatable {
    case option(String)
    case freeResponse(String)
}

struct AutoAdvanceState: Equatable {
    var isScheduled: Bool = false
    var scheduledForQuestionId: String? = nil
}
