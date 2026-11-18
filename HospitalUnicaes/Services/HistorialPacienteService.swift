import Foundation

/// Historial clínico visto por el propio paciente (HUNI-60). La API solo deja leerlo si el
/// `paciente_id` es el de la sesión (403 si no), así que se pide con el `paciente_id` de `/auth/me`.
protocol HistorialPacienteService: Sendable {
    /// `GET pacientes/{pacienteId}/historial`: expediente (alergias) y consultas con diagnósticos,
    /// recetas y órdenes de laboratorio, de la más reciente a la más antigua.
    func historial(pacienteId: UUID) async throws -> HistorialClinico
}

struct APIHistorialPacienteService: HistorialPacienteService {
    let client: APIClient

    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        try await client.send(.get, "pacientes/\(pacienteId.uuidString.lowercased())/historial")
    }
}
