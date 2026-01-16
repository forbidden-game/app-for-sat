import Combine
import Foundation
import StudentCore

protocol AnswerStore: AnyObject {
    subscript(questionId: String) -> AnswerValue? { get set }
    func clear(questionId: String)
    func allAnswers() -> [String: AnswerValue]
}

final class InMemoryAnswerStore: ObservableObject, AnswerStore {
    private var storage: [String: AnswerValue]

    init(initial: [String: AnswerValue] = [:]) {
        storage = initial
    }

    subscript(questionId: String) -> AnswerValue? {
        get { storage[questionId] }
        set {
            objectWillChange.send()
            storage[questionId] = newValue
        }
    }

    func clear(questionId: String) {
        guard storage[questionId] != nil else { return }
        objectWillChange.send()
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
