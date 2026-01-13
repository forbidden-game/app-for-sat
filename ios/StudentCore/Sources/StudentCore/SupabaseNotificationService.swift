import Foundation
import Supabase

public enum PushTokenPlatform: String, Codable {
    case apns
    case fcm
}

public final class SupabaseNotificationService {
    private let client: SupabaseClient
    private let tokenProvider: SupabaseAuthTokenProvider

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
        self.tokenProvider = SupabaseAuthTokenProvider(client: client)
    }

    public func registerPushToken(
        deviceToken: String,
        platform: PushTokenPlatform = .apns
    ) async throws {
        let trimmed = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "SupabaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid device token"])
        }

        struct Payload: Encodable {
            let device_token: String
            let platform: String
        }

        struct FunctionResponse: Decodable {
            let ok: Bool
        }

        let accessToken = try await tokenProvider.accessToken()
        let response: FunctionResponse = try await client.functions.invoke(
            "register_push_token",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(accessToken)",
                    "apikey": SupabaseConfig.anonKey,
                ],
                body: Payload(device_token: trimmed, platform: platform.rawValue)
            )
        )

        if response.ok != true {
            throw NSError(domain: "SupabaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to register push token"])
        }
    }
}
