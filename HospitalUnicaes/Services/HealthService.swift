import SwiftUI

/// Estado del backend (`GET /health`, HUNI-17). Público: no lleva token.
protocol HealthService: Sendable {
    func check() async throws -> HealthStatus
}

struct APIHealthService: HealthService {
    let client: APIClient

    func check() async throws -> HealthStatus {
        // `/health` vive en la raíz del servidor, fuera de `/api`.
        try await client.send(.get, "/health", authenticated: false)
    }
}

/// Como `/health` es público, el valor por defecto ya es el real (`API_BASE_URL`, sin token).
private struct HealthServiceKey: EnvironmentKey {
    static let defaultValue: any HealthService = APIHealthService(client: APIClient { nil })
}

extension EnvironmentValues {
    var healthService: any HealthService {
        get { self[HealthServiceKey.self] }
        set { self[HealthServiceKey.self] = newValue }
    }
}
