import Foundation
import StudentCore

final class AttemptInsightCache {
    static let shared = AttemptInsightCache()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "attemptInsightCache."

    func load(attemptId: String) -> AttemptInsight? {
        guard let data = defaults.data(forKey: key(for: attemptId)) else {
            return nil
        }
        return try? decoder.decode(AttemptInsight.self, from: data)
    }

    func save(_ insight: AttemptInsight) {
        guard let data = try? encoder.encode(insight) else { return }
        defaults.set(data, forKey: key(for: insight.attemptId))
    }

    private func key(for attemptId: String) -> String {
        keyPrefix + attemptId
    }
}
