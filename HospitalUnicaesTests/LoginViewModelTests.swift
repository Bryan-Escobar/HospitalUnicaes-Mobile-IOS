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

    @Test func mientrasEnviaMuestraElCargandoYNoReenvia() async {
        let (viewModel, _) = makeViewModel()
        let gate = AsyncGate()
        auth.signInGate = gate
        viewModel.email = "doctor@demo.test"
        viewModel.password = "Hospital2026"

        let envio = Task { await viewModel.signIn() }
        await esperar { viewModel.isLoading }
        #expect(viewModel.isLoading)
        #expect(!viewModel.canSubmit)

        await viewModel.signIn()
        gate.open()
        await envio.value

        #expect(auth.signInCalls.count == 1)
        #expect(!viewModel.isLoading)
    }

    @Test func sinCamposNoLlamaAlServicio() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.signIn()

        #expect(auth.signInCalls.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func sinInternetPideRevisarLaConexion() async {
        let (viewModel, session) = makeViewModel()
        auth.signInResult = .failure(URLError(.notConnectedToInternet))
        viewModel.email = "doctor@demo.test"
        viewModel.password = "x"

        await viewModel.signIn()

        #expect(viewModel.errorMessage == "No hay conexión. Revisa tu internet e intenta de nuevo.")
        #expect(session.state == .signedOut)
    }

    @Test func siLaApiFallaTrasElLoginSeCierraLaSesionYSeInformaElError() async {
        let (viewModel, session) = makeViewModel()
        me.meResult = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        viewModel.email = "doctor@demo.test"
        viewModel.password = "x"

        await viewModel.signIn()

        #expect(viewModel.errorMessage == "El servidor del hospital no está disponible en este momento. Intenta más tarde.")
        #expect(auth.signOutCount == 1)
        #expect(session.state == .signedOut)
    }

    @Test func reintentarTrasUnErrorLimpiaElMensaje() async {
        let (viewModel, session) = makeViewModel()
        auth.signInResult = .failure(AuthServiceError.invalidCredentials)
        viewModel.email = "doctor@demo.test"
        viewModel.password = "mala"
        await viewModel.signIn()
        #expect(viewModel.errorMessage != nil)

        auth.signInResult = .success(AppUser(id: UUID(), email: "doctor@demo.test"))
        viewModel.password = "Hospital2026"
        await viewModel.signIn()

        #expect(viewModel.errorMessage == nil)
        if case .signedIn = session.state {} else { Issue.record("Se esperaba una sesión iniciada") }
    }

    @Test func administradorNoEntraALaApp() async {
        let (viewModel, session) = makeViewModel()
        let admin = Me.fixture(rol: .administrador)
        me.meResult = .success(admin)
        viewModel.email = "admin@demo.test"
        viewModel.password = "x"

        await viewModel.signIn()

        #expect(session.state == .accesoNoDisponible(admin))
        #expect(viewModel.errorMessage == nil)
    }
}
