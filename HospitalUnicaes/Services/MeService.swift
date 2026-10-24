import Foundation

/// Perfil y registro de la cuenta (`/api/auth/*`, HUNI-38).
protocol MeService: Sendable {
    /// `GET /api/auth/me`: perfil, rol y paciente o personal asociado.
    func fetchMe() async throws -> Me
    /// `POST /api/auth/registro` (público): crea cuenta, perfil `paciente`, paciente y expediente.
    func registrar(_ request: RegistroPacienteRequest) async throws -> Me
}

enum MeServiceError: LocalizedError, Equatable {
    /// El registro simulado creó la cuenta en Supabase, pero Auth exige confirmar el correo.
    case confirmacionDeCorreoPendiente

    var errorDescription: String? {
        "Te enviamos un correo para confirmar tu cuenta. Confírmala y luego ingresa."
    }
}

struct APIMeService: MeService {
    let client: APIClient

    func fetchMe() async throws -> Me {
        try await client.send(.get, "auth/me")
    }

    func registrar(_ request: RegistroPacienteRequest) async throws -> Me {
        try await client.send(.post, "auth/registro", body: request, authenticated: false)
    }
}

/// Simula `/api/auth/*` mientras HUNI-38 no está desplegado (`USE_MOCK_ME = YES`).
///
/// El rol sale del correo de la sesión: `doctor@…`, `recepcion@…`, `admin@…`/`administrador@…`;
/// cualquier otro es `paciente`. El login sí es real (Supabase Auth).
struct MockMeService: MeService {
    let authService: AuthService
    var currentEmail: @Sendable () async -> String?

    init(authService: AuthService) {
        self.authService = authService
        self.currentEmail = { try? await authService.currentUser()?.email }
    }

    init(authService: AuthService, currentEmail: @escaping @Sendable () async -> String?) {
        self.authService = authService
        self.currentEmail = currentEmail
    }

    func fetchMe() async throws -> Me {
        guard let email = await currentEmail() else {
            throw APIError(statusCode: 401, code: "NO_AUTENTICADO", message: "Falta el token Bearer.")
        }
        return Self.me(email: email)
    }

    func registrar(_ request: RegistroPacienteRequest) async throws -> Me {
        // Sustituto de la API: crea la cuenta directo en Supabase Auth (el trigger
        // `handle_new_user` le pone rol `paciente`).
        guard try await authService.signUp(email: request.email, password: request.password) else {
            throw MeServiceError.confirmacionDeCorreoPendiente
        }
        return Self.me(email: request.email, nombres: request.nombres, apellidos: request.apellidos)
    }

    static func role(forEmail email: String) -> UserRole {
        let local = email.lowercased().split(separator: "@").first.map(String.init) ?? ""
        if local.hasPrefix("doctor") { return .doctor }
        if local.hasPrefix("recepcion") { return .recepcionista }
        if local.hasPrefix("admin") { return .administrador }
        return .paciente
    }

    static func me(email: String, nombres: String? = nil, apellidos: String? = nil) -> Me {
        let rol = role(forEmail: email)
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
            nombres: nombres ?? demo.nombres,
            apellidos: apellidos ?? demo.apellidos,
            telefono: "7000-0000",
            avatarUrl: nil,
            rol: rol,
            activo: true,
            pacienteId: rol == .paciente ? UUID() : nil,
            personal: personal
        )
    }
}
