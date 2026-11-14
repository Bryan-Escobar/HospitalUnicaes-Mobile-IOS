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
    func signOut() async throws {}
    func resetPassword(email: String) async throws {}
    func accessToken() async throws -> String? { nil }
    func sessionEvents() -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
}

struct PreviewHealthService: HealthService {
    func check() async throws -> HealthStatus {
        HealthStatus(status: "ok", timestamp: "2026-10-27T12:00:00.000Z", uptime: 120, database: .up)
    }
}

extension Me {
    static let previewDoctor = Me.preview(email: "doctor@demo.hospitalunicaes.test")
    static let previewPaciente = Me.preview(email: "paciente@demo.hospitalunicaes.test")
    static let previewRecepcion = Me.preview(email: "recepcion@demo.hospitalunicaes.test")
    static let previewAdmin = Me.preview(email: "administrador@demo.hospitalunicaes.test")

    /// Rol de un perfil de muestra según el correo: `doctor@…`, `recepcion@…`, `admin@…`/`administrador@…`;
    /// cualquier otro es `paciente`. Solo para Previews y `-HUPreviewEmail`.
    static func previewRole(forEmail email: String) -> UserRole {
        let local = email.lowercased().split(separator: "@").first.map(String.init) ?? ""
        if local.hasPrefix("doctor") { return .doctor }
        if local.hasPrefix("recepcion") { return .recepcionista }
        if local.hasPrefix("admin") { return .administrador }
        return .paciente
    }

    /// Perfil de muestra con datos ficticios para Previews y `-HUPreviewEmail`.
    static func preview(email: String) -> Me {
        let rol = previewRole(forEmail: email)
        let demo: (nombres: String, apellidos: String) = switch rol {
        case .administrador: ("Andrea", "Méndez Ruiz")
        case .doctor: ("Roberto", "Castillo Peña")
        case .recepcionista: ("Lucía", "Herrera Gómez")
        case .paciente: ("Carlos", "Martínez Rivas")
        }
        let personal: PersonalResumen? = switch rol {
        case .doctor:
            PersonalResumen(id: UUID(), tipo: .init(id: UUID(), nombre: "Médico"), especialidad: "Alergista", codigoEmpleado: "EMP-0002")
        case .recepcionista:
            PersonalResumen(id: UUID(), tipo: .init(id: UUID(), nombre: "Recepcionista"), especialidad: nil, codigoEmpleado: "EMP-0003")
        case .administrador, .paciente:
            nil
        }
        return Me(
            id: UUID(),
            email: email,
            nombres: demo.nombres,
            apellidos: demo.apellidos,
            telefono: "7000-0000",
            avatarUrl: nil,
            rol: rol,
            activo: true,
            pacienteId: rol == .paciente ? UUID() : nil,
            personal: personal
        )
    }
}

/// `MeService` en memoria para las Previews: nunca llama a la API.
struct PreviewMeService: MeService {
    var me: Me

    func fetchMe() async throws -> Me { me }
    func registrar(_ request: RegistroPacienteRequest) async throws -> Me { me }
}

extension SessionViewModel {
    static func preview(_ state: State = .signedOut) -> SessionViewModel {
        let email: String? = switch state {
        case .signedIn(let me), .accesoNoDisponible(let me): me.email
        default: nil
        }
        let me: Me = switch state {
        case .signedIn(let me), .accesoNoDisponible(let me): me
        default: .previewPaciente
        }
        return SessionViewModel(
            authService: PreviewAuthService(email: email),
            meService: PreviewMeService(me: me),
            state: state
        )
    }
}
#endif
