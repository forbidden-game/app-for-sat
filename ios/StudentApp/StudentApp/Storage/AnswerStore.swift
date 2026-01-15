import Combine
import Foundation
import StudentCore

protocol AnswerStore: AnyObject {
    subscript(questionId: String) -> AnswerValue? { get set }
    func clear(questionId: String)
    func allAnswers() -> [String: AnswerValue]
}

final class InMemoryAnswerStore: ObservableObject, AnswerStore {
    @Published private var storage: [String: AnswerValue]

    init(initial: [String: AnswerValue] = [:]) {
        storage = initial
    }

    subscript(questionId: String) -> AnswerValue? {
        get { storage[questionId] }
        set { storage[questionId] = newValue }
    }

    func clear(questionId: String) {
        storage.removeValue(forKey: questionId)
    }

    func allAnswers() -> [String: AnswerValue] {
        storage
    }

    func stringAnswers() -> [String: String] {
        storage.mapValues { value in
            value.displayString
        }
    }
}
