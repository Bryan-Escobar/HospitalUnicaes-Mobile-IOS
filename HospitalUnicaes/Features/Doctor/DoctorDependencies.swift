import Supabase
import SwiftUI

/// Servicios del flujo del doctor. `onIniciarConsulta` es el gancho de "Iniciar consulta"
/// en iOS-D3; HUNI-59 lo conecta con el formulario de nueva consulta (iOS-D7).
struct DoctorDependencies {
    var citas: any CitasService
    var pacientes: any PacientesService
    var hospitalizaciones: any HospitalizacionesService
    var onIniciarConsulta: @MainActor (Cita) -> Void

    static func live(supabase: SupabaseClient?, api: APIClient) -> DoctorDependencies {
        DoctorDependencies(
            citas: SupabaseCitasService(client: supabase),
            pacientes: APIPacientesService(client: api),
            hospitalizaciones: APIHospitalizacionesService(client: api),
            onIniciarConsulta: { _ in }
        )
    }
}

private struct DoctorDependenciesKey: EnvironmentKey {
    static let defaultValue = DoctorDependencies.live(
        supabase: nil,
        api: APIClient(baseURL: nil) { nil }
    )
}

extension EnvironmentValues {
    var doctorDependencies: DoctorDependencies {
        get { self[DoctorDependenciesKey.self] }
        set { self[DoctorDependenciesKey.self] = newValue }
    }
}
