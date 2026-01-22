import Foundation

enum InviteLinkBuilder {
    static func build(inviteCode: String?) -> URL {
        let trimmed = inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var components = URLComponents(string: AppConfig.friendInviteBaseURLString)
        if !trimmed.isEmpty {
            components?.queryItems = [
                URLQueryItem(name: "inviteCode", value: trimmed)
            ]
        }
        return components?.url ?? URL(string: AppConfig.friendInviteBaseURLDefault) ?? URL(string: "satprep://invite")!
    }
}
