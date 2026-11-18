import Foundation

/// Perfil y registro de la cuenta (`/api/auth/*`, HUNI-38).
protocol MeService: Sendable {
    /// `GET /api/auth/me`: perfil, rol y paciente o personal asociado.
    func fetchMe() async throws -> Me
    /// `POST /api/auth/me/conexion-app`: registra la apertura y devuelve la hora guardada.
    func registrarConexionApp() async throws -> Date
    /// `POST /api/auth/registro` (público): crea cuenta, perfil `paciente`, paciente y expediente.
    func registrar(_ request: RegistroPacienteRequest) async throws -> Me
}

enum MeServiceError: LocalizedError, Equatable {
    /// Supabase Auth exige confirmar el correo antes de iniciar sesión.
    case confirmacionDeCorreoPendiente

    var errorDescription: String? {
        "Te enviamos un correo para confirmar tu cuenta. Confírmala y luego ingresa."
    }
}

struct APIMeService: MeService {
    private struct ConexionApp: Decodable {
        let ultimaConexionAppAt: Date
    }

    let client: APIClient

    func fetchMe() async throws -> Me {
        try await client.send(.get, "auth/me")
    }

    func registrarConexionApp() async throws -> Date {
        let conexion: ConexionApp = try await client.send(.post, "auth/me/conexion-app")
        return conexion.ultimaConexionAppAt
    }

    func registrar(_ request: RegistroPacienteRequest) async throws -> Me {
        try await client.send(.post, "auth/registro", body: request, authenticated: false)
    }
}
