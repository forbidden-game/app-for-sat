import Supabase

public final class SupabaseService: @unchecked Sendable {
    public static let shared = SupabaseService()
    public let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }
}
