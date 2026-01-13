import Foundation
import Supabase

final class SupabaseAuthTokenProvider {
    private let client: SupabaseClient
    private let expiryLeeway: TimeInterval

    init(client: SupabaseClient, expiryLeeway: TimeInterval = 60) {
        self.client = client
        self.expiryLeeway = expiryLeeway
    }

    func accessToken(forceRefresh: Bool = false) async throws -> String {
        if forceRefresh {
            return try await refreshAccessToken()
        }

        let session = try await client.auth.session
#if DEBUG
        let now = Date().timeIntervalSince1970
        let exp = JwtUtils.expiration(from: session.accessToken)
        let expDelta = exp.map { Int($0 - now) }
        print("[AuthToken] session expired=\(session.isExpired) expIn=\(expDelta.map(String.init) ?? "n/a")")
#endif

        if shouldForceRefreshForIssuer(token: session.accessToken) || shouldRefresh(session: session) {
#if DEBUG
            print("[AuthToken] refreshing session due to issuer mismatch or expiring token")
#endif
            let refreshed = try await client.auth.refreshSession()
            return refreshed.accessToken
        }
        return session.accessToken
    }

    func refreshAccessToken() async throws -> String {
        let refreshed = try await client.auth.refreshSession()
        return refreshed.accessToken
    }

    private func shouldRefresh(session: Session) -> Bool {
        if session.isExpired { return true }
        guard let exp = JwtUtils.expiration(from: session.accessToken) else { return false }
        let now = Date().timeIntervalSince1970
        return exp <= now + expiryLeeway
    }

    private func shouldForceRefreshForIssuer(token: String) -> Bool {
        guard let issuer = JwtUtils.issuer(from: token) else { return false }
        guard let host = SupabaseConfig.url.host, !host.isEmpty else { return false }
        return issuer.contains(host) == false
    }
}
