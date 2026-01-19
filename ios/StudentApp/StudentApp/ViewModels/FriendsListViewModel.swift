import Combine
import Foundation
import StudentCore

@MainActor
final class FriendsListViewModel: ObservableObject {
    @Published var friends: [FriendThreadSummary] = []
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
}
