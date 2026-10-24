import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct SessionViewModelTests {
    let auth = FakeAuthService()
    let me = FakeMeService()

    private func makeSession() -> SessionViewModel {
        SessionViewModel(authService: auth, meService: me)
    }

    @Test func restoreSinSesionVaALogin() async {
        let session = makeSession()
        await session.restore()
        #expect(session.state == .signedOut)
        #expect(me.fetchCount == 0)
    }

    @Test(arguments: [UserRole.doctor, .paciente])
    func restoreConSesionEntraASuTabView(rol: UserRole) async {
        auth.storedUser = AppUser(id: UUID(), email: "x@demo.test")
        let perfil = Me.fixture(rol: rol)
        me.meResult = .success(perfil)
        let session = makeSession()

        await session.restore()

        #expect(session.state == .signedIn(perfil))
    }

    @Test(arguments: [UserRole.administrador, .recepcionista])
    func rolesSinAppVenAccesoNoDisponible(rol: UserRole) async {
        auth.storedUser = AppUser(id: UUID(), email: "x@demo.test")
        let perfil = Me.fixture(rol: rol)
        me.meResult = .success(perfil)
        let session = makeSession()

        await session.restore()

        #expect(session.state == .accesoNoDisponible(perfil))
    }

    @Test func refreshFallidoMuestraSesionExpirada() async {
        auth.currentUserError = AuthServiceError.sessionExpired
        let session = makeSession()
        await session.restore()
        #expect(session.state == .sessionExpired)
    }

    @Test func meCon401LimpiaLaSesion() async {
        auth.storedUser = AppUser(id: UUID(), email: "x@demo.test")
        me.meResult = .failure(APIError(statusCode: 401, code: "NO_AUTENTICADO"))
        let session = makeSession()

        await session.restore()

        #expect(session.state == .sessionExpired)
        #expect(auth.signOutCount == 1)
    }

    @Test func signInSiMeFallaCierraLaSesionYPropagaElError() async {
        me.meResult = .failure(APIError(statusCode: 403, code: "PERFIL_INCOMPLETO"))
        let session = makeSession()
        session.acknowledgeExpiredSession()

        await #expect(throws: APIError.self) {
            try await session.signIn(email: "a@b.co", password: "x")
        }
        #expect(session.state == .signedOut)
        #expect(auth.signOutCount == 1)
    }

    @Test func cerrarSesionLimpiaYVuelveALogin() async throws {
        let session = makeSession()
        try await session.signIn(email: "doctor@demo.test", password: "x")
        #expect(session.state == .signedIn(try me.meResult.get()))

        await session.signOut()

        #expect(session.state == .signedOut)
        #expect(auth.signOutCount == 1)
        #expect(auth.storedUser == nil)
    }

    @Test func signedOutInesperadoExpiraLaSesion() async throws {
        let session = makeSession()
        try await session.signIn(email: "doctor@demo.test", password: "x")

        session.handle(.tokenRefreshed)
        #expect(session.state != .sessionExpired)

        session.handle(.signedOut)
        #expect(session.state == .sessionExpired)

        session.acknowledgeExpiredSession()
        #expect(session.state == .signedOut)
    }

    @Test func signedOutTrasCierreManualNoMuestraExpirada() async throws {
        let session = makeSession()
        try await session.signIn(email: "doctor@demo.test", password: "x")
        await session.signOut()

        session.handle(.signedOut)

        #expect(session.state == .signedOut)
    }

    @Test func registroCreaPacienteEIniciaSesion() async throws {
        let session = makeSession()
        let request = RegistroPacienteRequest(nombres: "Ana", apellidos: "Rivas", email: "ana@correo.com", password: "Hospital2026")

        try await session.register(request)

        #expect(me.registros == [request])
        #expect(auth.signInCalls.map(\.email) == ["ana@correo.com"])
        guard case .signedIn(let perfil) = session.state else {
            Issue.record("Se esperaba signedIn, llegó \(session.state)")
            return
        }
        #expect(perfil.rol == .paciente)
    }
}
