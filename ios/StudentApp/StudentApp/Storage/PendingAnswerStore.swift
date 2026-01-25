import Foundation

struct PendingAnswerRecord: Codable, Identifiable, Equatable {
    let id: String
    let sessionId: String
    let questionId: String
    let answer: String?
    let durationMs: Int?
    let clientSubmissionId: String
    let createdAt: Date
    var retryCount: Int
}

@MainActor
final class PendingAnswerStore {
    static let shared = PendingAnswerStore()

    private var hasLoaded = false
    private var records: [PendingAnswerRecord] = []

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        records = loadFromDisk()
    }

    func records(for sessionId: String) -> [PendingAnswerRecord] {
        loadIfNeeded()
        return records.filter { $0.sessionId == sessionId }
    }

    func upsert(_ record: PendingAnswerRecord) {
        loadIfNeeded()
        records.removeAll { $0.sessionId == record.sessionId && $0.questionId == record.questionId }
        records.append(record)
        persist()
    }

    func removeRecord(sessionId: String, questionId: String) {
        loadIfNeeded()
        records.removeAll { $0.sessionId == sessionId && $0.questionId == questionId }
        persist()
    }

    func incrementRetry(for recordId: String) {
        loadIfNeeded()
        guard let index = records.firstIndex(where: { $0.id == recordId }) else { return }
        records[index].retryCount += 1
        persist()
    }

    private func persist() {
        do {
            let url = try storageURL()
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Best-effort persistence; keep in-memory state on failure.
        }
    }

    private func loadFromDisk() -> [PendingAnswerRecord] {
        do {
            let url = try storageURL()
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingAnswerRecord].self, from: data)
        } catch {
            return []
        }
    }

    private func storageURL() throws -> URL {
        let fileManager = FileManager.default
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "PendingAnswerStore", code: -1, userInfo: nil)
        }
        let directory = baseURL.appendingPathComponent("StudentApp", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("pending_attempts.json")
    }
}
