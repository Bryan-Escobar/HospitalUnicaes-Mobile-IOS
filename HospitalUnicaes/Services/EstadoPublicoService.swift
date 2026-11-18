import SwiftUI

/// Información pública del hospital (iOS-C5, HUNI-76): ocupación agregada, médicos de turno ahora y
/// avisos públicos vigentes. Es pública: se pide sin token, también desde el login.
protocol EstadoPublicoService: Sendable {
    func estado() async throws -> EstadoPublico
}

/// `GET /api/publico/estado` (HUNI-74). La API filtra lo privado en `public.estado_publico()`.
struct APIEstadoPublicoService: EstadoPublicoService {
    let client: APIClient

    func estado() async throws -> EstadoPublico {
        try await client.send(.get, "publico/estado", authenticated: false)
    }
}

/// Como el endpoint es público, el valor por defecto ya es el real (`API_BASE_URL`, sin token).
private struct EstadoPublicoServiceKey: EnvironmentKey {
    static let defaultValue: any EstadoPublicoService = APIEstadoPublicoService(client: APIClient { nil })
}

extension EnvironmentValues {
    var estadoPublicoService: any EstadoPublicoService {
        get { self[EstadoPublicoServiceKey.self] }
        set { self[EstadoPublicoServiceKey.self] = newValue }
    }
}
