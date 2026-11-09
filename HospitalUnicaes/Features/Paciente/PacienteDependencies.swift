import Supabase
import SwiftUI

/// Servicios del flujo del paciente. Se crean una vez en `HospitalUnicaesApp` con el mismo
/// `SupabaseClient` y `APIClient` de la sesión.
struct PacienteDependencies {
    var laboratorio: any LaboratorioPacienteService
    var laboratorioRealtime: any LaboratorioRealtimeService
    var resultadoArchivos: any ResultadoArchivoService

    static func live(supabase: SupabaseClient?, api: APIClient) -> PacienteDependencies {
        PacienteDependencies(
            laboratorio: APILaboratorioPacienteService(client: api),
            laboratorioRealtime: SupabaseLaboratorioRealtimeService(client: supabase),
            resultadoArchivos: URLSessionResultadoArchivoService()
        )
    }
}

private struct PacienteDependenciesKey: EnvironmentKey {
    static let defaultValue = PacienteDependencies.live(
        supabase: nil,
        api: APIClient(baseURL: nil) { nil }
    )
}

extension EnvironmentValues {
    var pacienteDependencies: PacienteDependencies {
        get { self[PacienteDependenciesKey.self] }
        set { self[PacienteDependenciesKey.self] = newValue }
    }
}
