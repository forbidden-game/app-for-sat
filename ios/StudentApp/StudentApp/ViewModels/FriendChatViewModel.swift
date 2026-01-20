import Combine
import Foundation
import StudentCore

@MainActor
final class FriendChatViewModel: ObservableObject {
    @Published var messages: [FriendMessage] = []
    @Published var draftText: String = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private let threadId: String
    private let service: SupabaseFriendsService

    init(threadId: String, service: SupabaseFriendsService = SupabaseFriendsService()) {
        self.threadId = threadId
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await service.fetchFriendMessages(threadId: threadId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func send() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            let sent = try await service.sendFriendMessage(threadId: threadId, text: trimmed)
            messages.append(sent)
            draftText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
