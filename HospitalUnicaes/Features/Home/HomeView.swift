import SwiftUI

struct HomeView: View {
    @Environment(SessionViewModel.self) private var session
    let user: AppUser

    var body: some View {
        NavigationStack {
            List {
                Section("Sesión") {
                    Text(user.email)
                }
                Section {
                    Button("Cerrar sesión", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            }
            .navigationTitle("Inicio")
        }
    }
}
