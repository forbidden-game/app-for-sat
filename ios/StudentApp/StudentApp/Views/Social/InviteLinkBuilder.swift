import Foundation

enum InviteLinkBuilder {
    static func build(userId: String) -> URL {
        let inviteCode = InviteCodeStore.code(for: userId)
        var components = URLComponents(string: AppConfig.friendInviteBaseURLString)
        components?.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "inviteCode", value: inviteCode)
        ]
        return components?.url ?? URL(string: AppConfig.friendInviteBaseURLDefault) ?? URL(string: "https://app.example.com/invite")!
    }
}

private enum InviteCodeStore {
    static func code(for userId: String) -> String {
        let key = "friendInviteCode.\(userId)"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
