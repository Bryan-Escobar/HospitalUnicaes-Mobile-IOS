import Foundation
import Supabase

/// Cambios de sesión que le importan a la app (el SDK refresca el token solo).
enum AuthSessionEvent: Equatable {
    case tokenRefreshed
    /// La sesión terminó: cierre manual, refresh fallido o sesión revocada.
    case signedOut
}

/// Autenticación. De Supabase solo se usa Auth: los datos de negocio
/// se piden al backend unificado (HospitalUnicaes-Api).
protocol AuthService: Sendable {
    /// Usuario de la sesión guardada en Keychain, refrescando el token si hace falta.
    /// `nil` si no hay sesión guardada; lanza `AuthServiceError.sessionExpired` si la había
    /// pero ya no se puede refrescar.
    func currentUser() async throws -> AppUser?
    func signIn(email: String, password: String) async throws -> AppUser
    /// Crea la cuenta directo en Supabase Auth. Solo lo usa `MockMeService`: en la app real
    /// el registro pasa por `POST /api/auth/registro`.
    /// - Returns: `true` si quedó con sesión; `false` si falta confirmar el correo.
    func signUp(email: String, password: String) async throws -> Bool
    func signOut() async throws
    func resetPassword(email: String) async throws
    /// Access token vigente para el header `Authorization: Bearer` de la API.
    func accessToken() async throws -> String?
    /// Eventos de sesión mientras la app está abierta.
    func sessionEvents() -> AsyncStream<AuthSessionEvent>
}

enum AuthServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidCredentials
    case emailNotConfirmed
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Supabase no está configurado. Crea Config/Secrets.xcconfig a partir de Secrets.example.xcconfig."
        case .invalidCredentials:
            "Correo o contraseña incorrectos"
        case .emailNotConfirmed:
            "Confirma tu correo antes de ingresar. Revisa tu bandeja de entrada."
        case .sessionExpired:
            "Tu sesión expiró."
        }
    }
}

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient?

    init() {
        if let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey {
            client = SupabaseClient(
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
        } else {
            client = nil
        }
    }

    func currentUser() async throws -> AppUser? {
        guard let client, client.auth.currentSession != nil else { return nil }
        do {
            return AppUser(try await client.auth.session.user)
        } catch let error as URLError {
            // Sin red no se descarta la sesión: el refresh se reintenta en el próximo uso.
            throw error
        } catch {
            try? await client.auth.signOut(scope: .local)
            throw AuthServiceError.sessionExpired
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        guard let client else { throw AuthServiceError.missingConfiguration }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AppUser(session.user)
        } catch let error as AuthError {
            switch error.errorCode {
            case .invalidCredentials: throw AuthServiceError.invalidCredentials
            case .emailNotConfirmed: throw AuthServiceError.emailNotConfirmed
            default: throw error
            }
        }
    }

    func signUp(email: String, password: String) async throws -> Bool {
        guard let client else { throw AuthServiceError.missingConfiguration }
        return try await client.auth.signUp(email: email, password: password).session != nil
    }

    func signOut() async throws {
        guard let client else { return }
        do {
            try await client.auth.signOut()
        } catch {
            // Si el servidor no responde, igual se borra la sesión del Keychain.
            try await client.auth.signOut(scope: .local)
        }
    }

    func resetPassword(email: String) async throws {
        guard let client else { throw AuthServiceError.missingConfiguration }
        try await client.auth.resetPasswordForEmail(email)
    }

    func accessToken() async throws -> String? {
        guard let client, client.auth.currentSession != nil else { return nil }
        return try await client.auth.session.accessToken
    }

    func sessionEvents() -> AsyncStream<AuthSessionEvent> {
        guard let client else { return AsyncStream { $0.finish() } }
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await change in changes {
                    switch change.event {
                    case .tokenRefreshed: continuation.yield(.tokenRefreshed)
                    case .signedOut: continuation.yield(.signedOut)
                    default: break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension AppUser {
    init(_ user: User) {
        self.init(id: user.id, email: user.email ?? "")
    }
}
