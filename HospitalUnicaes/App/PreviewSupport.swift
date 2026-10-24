#if DEBUG
import Foundation

/// Servicios en memoria para las Previews de Xcode (no tocan Supabase ni la API).
struct PreviewAuthService: AuthService {
    /// Correo de la "sesión guardada"; `nil` = sin sesión.
    var email: String?

    func currentUser() async throws -> AppUser? {
        email.map { AppUser(id: UUID(), email: $0) }
    }
    func signIn(email: String, password: String) async throws -> AppUser {
        try await Task.sleep(for: .seconds(1))
        throw AuthServiceError.invalidCredentials
    }
    func signUp(email: String, password: String) async throws -> Bool { true }
    func signOut() async throws {}
    func resetPassword(email: String) async throws {}
    func accessToken() async throws -> String? { nil }
    func sessionEvents() -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
}

extension Me {
    static let previewDoctor = MockMeService.me(email: "doctor@demo.hospitalunicaes.test")
    static let previewPaciente = MockMeService.me(email: "paciente@demo.hospitalunicaes.test")
    static let previewRecepcion = MockMeService.me(email: "recepcion@demo.hospitalunicaes.test")
    static let previewAdmin = MockMeService.me(email: "administrador@demo.hospitalunicaes.test")
}

extension SessionViewModel {
    static func preview(_ state: State = .signedOut) -> SessionViewModel {
        let email: String? = switch state {
        case .signedIn(let me), .accesoNoDisponible(let me): me.email
        default: nil
        }
        let auth = PreviewAuthService(email: email)
        return SessionViewModel(authService: auth, meService: MockMeService(authService: auth), state: state)
    }
}
#endif
