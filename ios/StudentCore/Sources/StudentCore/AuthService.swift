import Foundation
import Supabase

public struct AuthUser: Equatable {
    public let id: String
    public let email: String?
}

public final class AuthService {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    public func currentUser() -> AuthUser? {
        guard let user = client.auth.currentUser else { return nil }
        return AuthUser(id: user.id.uuidString, email: user.email)
    }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signIn(email: email, password: password)
        let user = session.user
        return AuthUser(id: user.id.uuidString, email: user.email)
    }

    public func signUp(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signUp(email: email, password: password)
        let user = session.user
        return AuthUser(id: user.id.uuidString, email: user.email)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }
}
