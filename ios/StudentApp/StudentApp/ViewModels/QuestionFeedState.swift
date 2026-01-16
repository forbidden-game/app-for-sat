import Combine
import Foundation
import StudentCore

@MainActor
final class QuestionFeedState: ObservableObject {
    @Published private(set) var currentIndex: Int
    @Published private(set) var inputState: QuestionInputState
    @Published private(set) var autoAdvanceState: AutoAdvanceState

    init(initialIndex: Int = 0) {
        currentIndex = initialIndex
        inputState = QuestionInputState()
        autoAdvanceState = AutoAdvanceState()
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
        if !isMultipleChoice, let answer = store[questionId] {
            next.freeResponse = answer.displayString
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

    func updateFreeResponse(_ value: String) {
        var next = inputState
        next.freeResponse = value
        inputState = next
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
