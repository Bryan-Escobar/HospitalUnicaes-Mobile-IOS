import Foundation
import Supabase

/// Un solo `SupabaseClient` para Auth y para leer `v_citas` (PostgREST, HUNI-51).
enum SupabaseClientFactory {
    static func make() -> SupabaseClient? {
        guard let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(
                    // La sesión (access + refresh token) vive en el Keychain del dispositivo.
                    storage: KeychainLocalStorage(service: "sv.edu.catolica.hospitalunicaes.auth"),
                    // Emite la sesión guardada al instante; `currentUser()` la valida aparte.
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    /// Decoder de PostgREST: fechas ISO 8601 y claves tal cual llegan de la vista (snake_case).
    static var postgrestDecoder: JSONDecoder {
        PostgrestClient.Configuration.jsonDecoder
    }
}
