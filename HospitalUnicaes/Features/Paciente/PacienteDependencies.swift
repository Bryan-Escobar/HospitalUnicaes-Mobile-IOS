import Supabase
import SwiftUI

/// Servicios del flujo del paciente. Se crean una vez en `HospitalUnicaesApp` con el mismo
/// `SupabaseClient` y `APIClient` de la sesión.
struct PacienteDependencies {
    var ambulancias: any AmbulanciaService
    var ambulanciaRealtime: any AmbulanciaRealtimeService
    var ubicacion: @MainActor () -> any UbicacionService

    static func live(supabase: SupabaseClient?, api: APIClient) -> PacienteDependencies {
        PacienteDependencies(
            ambulancias: APIAmbulanciaService(client: api),
            ambulanciaRealtime: SupabaseAmbulanciaRealtimeService(client: supabase),
            ubicacion: { CoreLocationUbicacionService() }
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
