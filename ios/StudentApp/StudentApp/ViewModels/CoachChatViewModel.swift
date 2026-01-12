import Combine
import Foundation
import StudentCore

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published var messages: [CoachThreadMessage] = []
    @Published var draftText: String = ""
    @Published var errorMessage: String?
    @Published var isSending = false

    private let studentId: String
    private let service: SupabaseCoachService

    init(studentId: String, service: SupabaseCoachService = SupabaseCoachService()) {
        self.studentId = studentId
        self.service = service
    }

    func load() async {
        do {
            messages = try await service.fetchThreadMessages(studentId: studentId, limit: 80)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            try await service.startRealtime(studentId: studentId) { [weak self] msg in
                guard let self else { return }
                self.upsertMessage(msg)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() async {
        await service.stopRealtime()
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            _ = try await service.sendMessage(text: text)
            draftText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertMessage(_ msg: CoachThreadMessage) {
        if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
            messages[idx] = msg
        } else {
            messages.append(msg)
            messages.sort(by: { $0.createdAt < $1.createdAt })
        }
    }
}
