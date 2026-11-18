import SwiftUI

/// Decide qué flujo mostrar según la sesión y el rol de `/api/auth/me`.
struct RootView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(\.pacienteDependencies) private var pacienteDependencies
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let perfilActivo = scenePhase == .active ? session.perfilActivoID : nil
        Group {
            switch session.state {
            case .loading:
                SplashView()
            case .signedOut:
                LoginView(viewModel: LoginViewModel(session: session))
            case .signedIn(let me):
                switch me.rol {
                case .doctor:
                    DoctorTabView(me: me)
                default:
                    PacienteTabView(me: me, dependencies: pacienteDependencies)
                }
            case .accesoNoDisponible(let me):
                AccesoNoDisponibleView(me: me)
            case .sessionExpired:
                SessionExpiredView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.state)
        .task {
            if case .loading = session.state { await session.restore() }
        }
        .task(id: perfilActivo) {
            guard let perfilActivo else { return }
            await session.registrarConexionApp(perfilID: perfilActivo)
        }
    }
}
