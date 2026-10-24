import Foundation
import Observation

/// Estado global de autenticación compartido por toda la app.
@MainActor
@Observable
final class SessionViewModel {
    enum State: Equatable {
        /// Splash: restaurando la sesión del Keychain y pidiendo `/me`.
        case loading
        case signedOut
        /// Doctor o paciente: entra a su TabView.
        case signedIn(Me)
        /// Administrador o recepcionista: la app iOS no es para su rol.
        case accesoNoDisponible(Me)
        /// El refresh del token falló o `/me` respondió 401.
        case sessionExpired
    }

    private(set) var state: State = .loading

    private let authService: AuthService
    private let meService: MeService
    private var eventsTask: Task<Void, Never>?

    init(authService: AuthService, meService: MeService, state: State = .loading) {
        self.authService = authService
        self.meService = meService
        self.state = state
    }

    /// Splash (iOS-C1): restaura la sesión guardada y enruta por rol.
    func restore() async {
        listenToSessionEvents()
        do {
            guard try await authService.currentUser() != nil else {
                state = .signedOut
                return
            }
            try await loadMe()
        } catch AuthServiceError.sessionExpired {
            state = .sessionExpired
        } catch let error as APIError where error.isUnauthorized {
            await expireSession()
        } catch {
            // Sin red o API caída: se vuelve a Login conservando la sesión del Keychain.
            state = .signedOut
        }
    }

    /// Login (iOS-C2). Si `/me` falla, se cierra la sesión recién abierta y se propaga el error.
    func signIn(email: String, password: String) async throws {
        _ = try await authService.signIn(email: email, password: password)
        do {
            try await loadMe()
        } catch {
            await discardSession()
            throw error
        }
    }

    /// Registro (iOS-C3): crea el paciente por la API y luego inicia sesión con el SDK.
    func register(_ request: RegistroPacienteRequest) async throws {
        _ = try await meService.registrar(request)
        try await signIn(email: request.email, password: request.password)
    }

    /// Recuperar contraseña (iOS-C4): misma respuesta exista o no el correo.
    func resetPassword(email: String) async throws {
        try await authService.resetPassword(email: email)
    }

    func signOut() async {
        await discardSession()
        state = .signedOut
    }

    /// "Ingresar de nuevo" desde la pantalla de sesión expirada.
    func acknowledgeExpiredSession() {
        state = .signedOut
    }

    // MARK: Privado

    private func loadMe() async throws {
        let me = try await meService.fetchMe()
        state = me.rol.usesIOSApp ? .signedIn(me) : .accesoNoDisponible(me)
    }

    private func discardSession() async {
        try? await authService.signOut()
    }

    private func expireSession() async {
        await discardSession()
        state = .sessionExpired
    }

    private func listenToSessionEvents() {
        guard eventsTask == nil else { return }
        let events = authService.sessionEvents()
        eventsTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    /// Un `signedOut` que no vino de `signOut()` (refresh fallido, sesión revocada) expira la sesión.
    /// El cierre manual ya dejó `state` en `.signedOut` antes de que llegue el evento.
    func handle(_ event: AuthSessionEvent) {
        guard event == .signedOut else { return }
        switch state {
        case .signedIn, .accesoNoDisponible:
            state = .sessionExpired
        case .loading, .signedOut, .sessionExpired:
            break
        }
    }
}
