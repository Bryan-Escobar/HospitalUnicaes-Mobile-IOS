import Foundation
import Observation
import OSLog

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
    private(set) var errorConexionApp: String?

    var perfilActivoID: UUID? { perfilAutenticado?.id }

    var ultimaConexionAppAt: Date? { perfilAutenticado?.ultimaConexionAppAt }

    private var perfilAutenticado: Me? {
        switch state {
        case .signedIn(let me), .accesoNoDisponible(let me): me
        case .loading, .signedOut, .sessionExpired: nil
        }
    }

    private let authService: AuthService
    private let meService: MeService
    private var eventsTask: Task<Void, Never>?
    private let conexionLogger = Logger(subsystem: "HospitalUnicaes", category: "ConexionApp")

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

    /// SwiftUI cancela esta tarea al dejar de estar activa la app o al cambiar de perfil.
    /// El personal que mantiene la app abierta puede registrar asistencia al comenzar un turno.
    func mantenerConexionApp(
        perfilID: UUID,
        esperar: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async {
        while !Task.isCancelled, perfilActivoID == perfilID {
            await registrarConexionApp(perfilID: perfilID)
            guard perfilActivoID == perfilID else { return }

            let intervalo: Duration
            if errorConexionApp != nil {
                intervalo = .seconds(15)
            } else if perfilAutenticado?.personal != nil {
                intervalo = .seconds(60)
            } else {
                return
            }
            do {
                try await esperar(intervalo)
            } catch {
                return
            }
        }
    }

    func registrarConexionApp(perfilID: UUID) async {
        guard !Task.isCancelled, perfilActivoID == perfilID else { return }
        do {
            let fecha = try await meService.registrarConexionApp()
            guard !Task.isCancelled, var me = perfilAutenticado, me.id == perfilID else { return }
            me.ultimaConexionAppAt = fecha
            state = me.rol.usesIOSApp ? .signedIn(me) : .accesoNoDisponible(me)
            errorConexionApp = nil
        } catch {
            guard !Task.isCancelled, perfilActivoID == perfilID else { return }
            if let respuesta = error as? APIError {
                if errorConexionApp == nil {
                    conexionLogger.warning("El registro de conexión respondió HTTP \(respuesta.statusCode, privacy: .public).")
                }
                errorConexionApp = respuesta.statusCode == 404
                    ? "La API configurada todavía no tiene habilitado el registro de conexión."
                    : "No se pudo registrar la conexión."
            } else {
                if errorConexionApp == nil {
                    let tipo = String(describing: type(of: error))
                    conexionLogger.warning("Falló el registro de conexión: \(tipo, privacy: .public).")
                }
                errorConexionApp = "No se pudo registrar la conexión."
            }
        }
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
        errorConexionApp = nil
        state = me.rol.usesIOSApp ? .signedIn(me) : .accesoNoDisponible(me)
    }

    private func discardSession() async {
        try? await authService.signOut()
        // Los PDF de resultados descargados no sobreviven a la sesión.
        URLSessionResultadoArchivoService().borrar(nil)
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
