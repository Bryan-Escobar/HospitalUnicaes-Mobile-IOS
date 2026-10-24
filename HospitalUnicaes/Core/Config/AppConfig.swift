import Foundation

/// Valores por ambiente leídos del Info.plist, que a su vez los toma de
/// `Config/Dev.xcconfig` (Debug) o `Config/Prod.xcconfig` (Release).
/// Si un valor falta, la propiedad es `nil` y la app sigue abriendo.
enum AppConfig {
    static let apiBaseURL = url(for: "API_BASE_URL")
    static let supabaseURL = url(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")
    /// `USE_MOCK_ME = YES` simula `/api/auth/me` y `/api/auth/registro` (ver `MockMeService`).
    static let useMockMe = string(for: "USE_MOCK_ME")?.uppercased() == "YES"

    static var isSupabaseConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }

    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func url(for key: String) -> URL? {
        string(for: key).flatMap(URL.init(string:))
    }
}
