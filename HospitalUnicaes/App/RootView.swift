import SwiftUI

/// Decide qué flujo mostrar según la sesión y el rol de `/api/auth/me`.
struct RootView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
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
                    PacienteTabView(me: me)
                }
            case .accesoNoDisponible(let me):
                AccesoNoDisponibleView(me: me)
            case .sessionExpired:
                SessionExpiredView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.state)
        .task { await session.restore() }
    }
}
