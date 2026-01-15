import Combine
import Foundation
import StudentCore

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published var messages: [CoachThreadMessage] = []
    @Published var draftText: String = ""
    @Published var errorMessage: String?
    @Published var isSending = false
    @Published var promptText: String = "问老师一个问题…"

    private let studentId: String
    private let linkedAttemptId: String?
    private let service: SupabaseCoachService
    private var pollingTask: Task<Void, Never>?
    private var promptTask: Task<Void, Never>?
    private var promptIndex = 0
    private var promptCandidates: [String] = []

    init(
        studentId: String,
        linkedAttemptId: String? = nil,
        initialDraftText: String? = nil,
        service: SupabaseCoachService = SupabaseCoachService()
    ) {
        self.studentId = studentId
        self.linkedAttemptId = linkedAttemptId
        self.service = service
        self.draftText = initialDraftText ?? ""
    }

    func load() async {
        do {
            messages = try await service.fetchThreadMessages(studentId: studentId, limit: 80)
        } catch {
            errorMessage = UserFacingError.message(error)
        }

        await loadPromptCandidates()

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
        promptTask?.cancel()
        promptTask = nil
        await service.stopRealtime()
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            _ = try await service.sendMessage(text: text, linkedAttemptId: linkedAttemptId)
            draftText = ""
            advancePrompt()
        } catch {
            errorMessage = UserFacingError.message(error)
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

    private func startPolling() {
        if pollingTask != nil {
            return
        }

        let studentId = self.studentId
        let service = self.service

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let latest = try await service.fetchThreadMessages(studentId: studentId, limit: 80)
                    await MainActor.run {
                        self?.messages = latest
                    }
                } catch {
                    // Best-effort: keep polling silently; UI can still send.
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func loadPromptCandidates() async {
        do {
            let snapshot = try await service.fetchStudentSnapshot(studentId: studentId)
            promptCandidates = buildPromptCandidates(snapshot: snapshot)
        } catch {
            promptCandidates = fallbackPromptCandidates()
        }

        if promptCandidates.isEmpty {
            promptCandidates = fallbackPromptCandidates()
        }

        promptIndex = 0
        promptText = promptCandidates.first ?? "问老师一个问题…"
        startPromptCycle()
    }

    private func startPromptCycle() {
        promptTask?.cancel()
        promptTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                await MainActor.run {
                    self?.advancePrompt()
                }
            }
        }
    }

    private func advancePrompt() {
        guard !promptCandidates.isEmpty else { return }
        promptIndex = (promptIndex + 1) % promptCandidates.count
        promptText = promptCandidates[promptIndex]
    }

    private func buildPromptCandidates(snapshot: StudentSnapshot?) -> [String] {
        var candidates: [String] = []

        if let notes = snapshot?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            candidates.append(notes)
        }

        if let weakStep = extractString(from: snapshot?.weakStepsTop.first) {
            candidates.append("要不要再练一下「\(weakStep)」？")
        }

        if let weakProcedure = extractString(from: snapshot?.weakProceduresTop.first) {
            candidates.append("我们可以从「\(weakProcedure)」先复盘。")
        }

        if let errorMode = extractString(from: snapshot?.commonErrorModesTop.first) {
            candidates.append("我注意到你在「\(errorMode)」容易出错，要不要专练？")
        }

        candidates.append(contentsOf: fallbackPromptCandidates())
        return Array(LinkedHashSet(items: candidates).items)
    }

    private func fallbackPromptCandidates() -> [String] {
        [
            "最近学习节奏还好吗？需要我安排 10 分钟轻量练习吗？",
            "可以用语音说给我听，我来帮你拆步骤。",
            "拍张题发我，我帮你定位关键步骤。",
            "要不要我给你出一道同类型小题？"
        ]
    }

    private func extractString(from value: JSONValue?) -> String? {
        guard let value else { return nil }

        switch value {
        case .string(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .number(let number):
            return String(format: "%.0f", number)
        case .object(let dict):
            let keys = ["name", "label", "title", "skill", "step", "topic", "text"]
            for key in keys {
                if let candidate = extractString(from: dict[key]) {
                    return candidate
                }
            }
            for (_, nested) in dict {
                if let candidate = extractString(from: nested) {
                    return candidate
                }
            }
            return nil
        case .array(let items):
            for item in items {
                if let candidate = extractString(from: item) {
                    return candidate
                }
            }
            return nil
        case .bool, .null:
            return nil
        }
    }
}

private struct LinkedHashSet<Element: Hashable> {
    private(set) var items: [Element] = []
    private var seen: Set<Element> = []

    init(items: [Element]) {
        for item in items {
            insert(item)
        }
    }

    mutating func insert(_ item: Element) {
        if seen.insert(item).inserted {
            items.append(item)
        }
    }
}
