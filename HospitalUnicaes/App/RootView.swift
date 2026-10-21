import SwiftUI

/// Decide qué flujo mostrar según el estado de la sesión.
struct RootView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView("Cargando…")
            case .signedOut:
                LoginView(viewModel: LoginViewModel(session: session))
            case .signedIn(let user):
                HomeView(user: user)
            }
        }
        .task { await session.restore() }
    }
}
