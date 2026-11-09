import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct RecuperarContrasenaViewModelTests {
    let auth = FakeAuthService()
    let me = FakeMeService()

    private func makeViewModel() -> RecuperarContrasenaViewModel {
        let session = SessionViewModel(authService: auth, meService: me, state: .signedOut)
        return RecuperarContrasenaViewModel(session: session)
    }

    @Test func correoInvalidoNoEnvia() async {
        let viewModel = makeViewModel()
        viewModel.email = "no-es-correo"
        #expect(!viewModel.canSubmit)

        await viewModel.send()

        #expect(auth.resetEmails.isEmpty)
        #expect(!viewModel.didSend)
    }

    @Test func correoValidoPideElEnlaceYRecortaEspacios() async {
        let viewModel = makeViewModel()
        viewModel.email = " Ana@Correo.com "

        await viewModel.send()

        #expect(auth.resetEmails == ["Ana@Correo.com"])
        #expect(viewModel.didSend)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func sinConexionMuestraErrorYNoConfirmaElEnvio() async {
        auth.resetError = URLError(.notConnectedToInternet)
        let viewModel = makeViewModel()
        viewModel.email = "ana@correo.com"

        await viewModel.send()

        #expect(viewModel.errorMessage == "No hay conexión. Revisa tu internet e intenta de nuevo.")
        #expect(!viewModel.didSend)
    }

    @Test func supabaseSinConfigurarMuestraElError() async {
        auth.resetError = AuthServiceError.missingConfiguration
        let viewModel = makeViewModel()
        viewModel.email = "ana@correo.com"

        await viewModel.send()

        #expect(viewModel.errorMessage == AuthServiceError.missingConfiguration.localizedDescription)
        #expect(!viewModel.didSend)
    }

    @Test func unCorreoInexistenteSeMuestraComoEnviado() async {
        auth.resetError = NSError(domain: "test", code: 1)
        let viewModel = makeViewModel()
        viewModel.email = "nadie@correo.com"

        await viewModel.send()

        #expect(viewModel.didSend)
        #expect(viewModel.errorMessage == nil)
    }
}
