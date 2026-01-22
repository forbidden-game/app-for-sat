import Combine
import Foundation
import StudentCore

@MainActor
final class FriendsListViewModel: ObservableObject {
    @Published var friends: [FriendThreadSummary] = []
    @Published var inviteCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: SupabaseFriendsService

    init(service: SupabaseFriendsService = SupabaseFriendsService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            friends = try await service.fetchFriendThreads()
        } catch {
            errorMessage = error.localizedDescription
            friends = []
        }
        isLoading = false
    }

    func loadInviteCode() async {
        do {
            inviteCode = try await service.getMyFriendInviteCode()
        } catch {
            errorMessage = error.localizedDescription
            inviteCode = nil
        }
    }

    func redeemInvite(code: String) async throws -> FriendInviteRedeemResult {
        try await service.redeemFriendInvite(code: code)
    }
}
