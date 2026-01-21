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
    private var pollingTask: Task<Void, Never>?
    private var remoteMessages: [CoachThreadMessage] = []

    init(
        studentId: String,
        initialDraftText: String? = nil,
        service: SupabaseCoachService = SupabaseCoachService()
    ) {
        self.studentId = studentId
        self.service = service
        self.draftText = initialDraftText ?? ""
    }

    deinit {
        pollingTask?.cancel()
        pollingTask = nil
        Task { await service.stopRealtime() }
    }

    func load() async {
        errorMessage = nil

        do {
            remoteMessages = try await service.fetchThreadMessages(studentId: studentId, limit: 80)
            messages = mergeMessages(remoteMessages)
        } catch {
            errorMessage = UserFacingError.message(error)
        }

        do {
            try await service.startRealtime(studentId: studentId) { [weak self] msg in
                guard let self else { return }
                self.upsertMessage(msg)
            }
        } catch {
            // Realtime is best-effort; if it fails (e.g. websocket blocked), fall back to polling.
            startPolling()
        }
    }

    func stop() async {
        pollingTask?.cancel()
        pollingTask = nil
        await service.stopRealtime()
    }

    @discardableResult
    func send(linkedAttemptId: String?, replyToMessageId: String?) async -> Bool {
        if isSending {
            return false
        }

        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let messageId = try await service.sendMessage(
                text: text,
                linkedAttemptId: linkedAttemptId,
                replyToMessageId: replyToMessageId
            )
            let newMessage = CoachThreadMessage(
                id: messageId,
                role: .user,
                content: CoachMessageContent(text: text),
                linkedAttemptId: linkedAttemptId,
                replyToMessageId: replyToMessageId,
                createdAt: Date()
            )
            upsertMessage(newMessage)
            draftText = ""
            return true
        } catch {
            errorMessage = UserFacingError.message(error)
            return false
        }
    }

    private func upsertMessage(_ msg: CoachThreadMessage) {
        if let idx = remoteMessages.firstIndex(where: { $0.id == msg.id }) {
            remoteMessages[idx] = msg
        } else {
            remoteMessages.append(msg)
        }
        messages = mergeMessages(remoteMessages)
    }

    private func startPolling() {
        if pollingTask != nil {
            return
        }

        let studentId = self.studentId
        let service = self.service

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }

                do {
                    let latest = try await service.fetchThreadMessages(studentId: studentId, limit: 80)
                    await MainActor.run {
                        guard let self else { return }
                        self.remoteMessages = latest
                        self.messages = self.mergeMessages(latest)
                    }
                } catch {
                    // Best-effort: keep polling silently; UI can still send.
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func mergeMessages(_ messages: [CoachThreadMessage]) -> [CoachThreadMessage] {
        messages.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }
}
