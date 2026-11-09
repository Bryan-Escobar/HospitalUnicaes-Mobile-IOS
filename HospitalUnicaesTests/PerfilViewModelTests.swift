import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct PerfilViewModelTests {
    let auth = FakeAuthService()
    let me = FakeMeService()
    let health = FakeHealthService()

    @Test func muestraNombreYFilasDelPerfil() {
        let perfil = Me.fixture(rol: .doctor, especialidad: "Alergista")
        let viewModel = PerfilViewModel(me: perfil, health: health)

        #expect(viewModel.nombre == "Ana Rivas")
        #expect(viewModel.rolYTipo == "Doctor · Alergista")
        #expect(viewModel.rows.map(\.label) == ["Correo", "Teléfono", "Rol y tipo"])
        #expect(viewModel.rows.map(\.value) == ["doctor@demo.test", "—", "Doctor · Alergista"])
    }

    @Test func pacienteSinTelefonoMuestraGuion() {
        var perfil = Me.fixture(rol: .paciente)
        perfil = Me(
            id: perfil.id,
            email: nil,
            nombres: perfil.nombres,
            apellidos: perfil.apellidos,
            telefono: nil,
            avatarUrl: nil,
            rol: .paciente,
            activo: true,
            pacienteId: perfil.pacienteId,
            personal: nil
        )
        let viewModel = PerfilViewModel(me: perfil, health: health)

        #expect(viewModel.rows.map(\.value) == ["—", "—", "Paciente"])
    }

    @Test func cerrarSesionVuelveALogin() async {
        let session = SessionViewModel(authService: auth, meService: me, state: .signedIn(.fixture(rol: .paciente)))
        let viewModel = PerfilViewModel(me: .fixture(rol: .paciente), health: health)

        await viewModel.signOut(using: session)

        #expect(session.state == .signedOut)
        #expect(auth.signOutCount == 1)
        #expect(!viewModel.isSigningOut)
    }

    @Test func servidorEnLinea() async {
        let viewModel = PerfilViewModel(me: .fixture(rol: .doctor), health: health)
        #expect(viewModel.serverStatus == .checking)

        await viewModel.checkServer()

        #expect(viewModel.serverStatus == .online)
    }

    @Test func servidorSinBaseDeDatos() async {
        health.result = .success(.fixture(database: .down))
        let viewModel = PerfilViewModel(me: .fixture(rol: .doctor), health: health)

        await viewModel.checkServer()

        #expect(viewModel.serverStatus == .degraded)
    }

    @Test func servidorCaidoMuestraMensaje() async {
        health.result = .failure(APIError(statusCode: 503, code: "HTTP_503"))
        let viewModel = PerfilViewModel(me: .fixture(rol: .doctor), health: health)

        await viewModel.checkServer()

        #expect(viewModel.serverStatus == .offline(
            "El servidor del hospital no está disponible en este momento. Intenta más tarde."
        ))
    }
}
