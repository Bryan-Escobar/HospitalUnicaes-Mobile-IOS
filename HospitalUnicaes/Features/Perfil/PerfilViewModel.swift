import Foundation
import Observation

/// iOS-C7 Perfil: datos de `/me`, estado del servidor (`/health`) y cierre de sesión con confirmación.
@MainActor
@Observable
final class PerfilViewModel {
    struct Row: Identifiable, Equatable {
        let label: String
        let value: String
        var id: String { label }
    }

    enum ServerStatus: Equatable {
        case checking
        case online
        /// El proceso responde pero la base de datos no.
        case degraded
        case offline(String)
    }

    let me: Me
    var isConfirmingSignOut = false
    private(set) var isSigningOut = false
    private(set) var serverStatus: ServerStatus = .checking

    private let health: any HealthService

    init(me: Me, health: any HealthService) {
        self.me = me
        self.health = health
    }

    var nombre: String { me.nombreCompleto }
    var rolYTipo: String { me.rolYTipo }

    var rows: [Row] {
        [
            Row(label: "Correo", value: me.email ?? "—"),
            Row(label: "Teléfono", value: me.telefono ?? "—"),
            Row(label: "Rol y tipo", value: me.rolYTipo),
        ]
    }

    func checkServer() async {
        serverStatus = .checking
        do {
            let status = try await health.check()
            serverStatus = status.database == .up ? .online : .degraded
        } catch {
            serverStatus = .offline(UserFacingError.message(for: error))
        }
    }

    func signOut(using session: SessionViewModel) async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}
