import Foundation
import Observation

/// iOS-C7 Perfil: datos de `/me` y cierre de sesión con confirmación.
@MainActor
@Observable
final class PerfilViewModel {
    struct Row: Identifiable, Equatable {
        let label: String
        let value: String
        var id: String { label }
    }

    let me: Me
    var isConfirmingSignOut = false
    private(set) var isSigningOut = false

    init(me: Me) {
        self.me = me
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

    func signOut(using session: SessionViewModel) async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}
