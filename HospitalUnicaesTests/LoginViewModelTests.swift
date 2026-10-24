import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct LoginViewModelTests {
    let auth = FakeAuthService()
    let me = FakeMeService()

    private func makeViewModel(configured: Bool = true) -> (LoginViewModel, SessionViewModel) {
        let session = SessionViewModel(authService: auth, meService: me, state: .signedOut)
        return (LoginViewModel(session: session, isSupabaseConfigured: configured), session)
    }

    @Test func noSePuedeEnviarVacio() {
        let (viewModel, _) = makeViewModel()
        #expect(!viewModel.canSubmit)
        viewModel.email = "  "
        viewModel.password = "x"
        #expect(!viewModel.canSubmit)
        viewModel.email = "doctor@demo.test"
        #expect(viewModel.canSubmit)
    }

    @Test func doctorEntraASuTabView() async {
        let (viewModel, session) = makeViewModel()
        let doctor = Me.fixture(rol: .doctor, especialidad: "Alergista")
        me.meResult = .success(doctor)
        viewModel.email = " doctor@demo.test "
        viewModel.password = "Hospital2026"

        await viewModel.signIn()

        #expect(session.state == .signedIn(doctor))
        #expect(auth.signInCalls.first?.email == "doctor@demo.test")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func credencialesInvalidasMuestranElMensajeYQuitanElCargando() async {
        let (viewModel, session) = makeViewModel()
        auth.signInResult = .failure(AuthServiceError.invalidCredentials)
        viewModel.email = "doctor@demo.test"
        viewModel.password = "mala"

        await viewModel.signIn()

        #expect(viewModel.errorMessage == "Correo o contraseña incorrectos")
        #expect(!viewModel.isLoading)
        #expect(viewModel.canSubmit)
        #expect(session.state == .signedOut)

        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)
    }

    @Test func sinSupabaseConfiguradoLoIndica() async {
        let (viewModel, _) = makeViewModel(configured: false)
        auth.signInResult = .failure(AuthServiceError.missingConfiguration)
        viewModel.email = "doctor@demo.test"
        viewModel.password = "x"

        await viewModel.signIn()

        #expect(!viewModel.isSupabaseConfigured)
        #expect(viewModel.errorMessage?.contains("Supabase no está configurado") == true)
    }

    @Test func perfilIncompletoTieneMensajePropio() async {
        let (viewModel, _) = makeViewModel()
        me.meResult = .failure(APIError(statusCode: 403, code: "PERFIL_INCOMPLETO"))
        viewModel.email = "doctor@demo.test"
        viewModel.password = "x"

        await viewModel.signIn()

        #expect(viewModel.errorMessage?.contains("no tiene un perfil") == true)
        #expect(auth.signOutCount == 1)
    }
}
