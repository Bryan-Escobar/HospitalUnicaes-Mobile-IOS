import Foundation
import Supabase

/// Autenticación. De Supabase solo se usa Auth: los datos de negocio
/// se piden al backend unificado (HospitalUnicaes-Api).
protocol AuthService {
    func currentUser() async -> AppUser?
    func signIn(email: String, password: String) async throws -> AppUser
    func signOut() async throws
}

enum AuthServiceError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        "Supabase no está configurado. Crea Config/Secrets.xcconfig a partir de Secrets.example.xcconfig."
    }
}

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient?

    init() {
        if let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        } else {
            client = nil
        }
    }

    func currentUser() async -> AppUser? {
        guard let client, let session = try? await client.auth.session else { return nil }
        return AppUser(id: session.user.id, email: session.user.email ?? "")
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        guard let client else { throw AuthServiceError.missingConfiguration }
        let session = try await client.auth.signIn(email: email, password: password)
        return AppUser(id: session.user.id, email: session.user.email ?? "")
    }

    func signOut() async throws {
        try await client?.auth.signOut()
    }
}
