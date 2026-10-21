import SwiftUI

@main
struct HospitalUnicaesApp: App {
    @State private var session = SessionViewModel(authService: SupabaseAuthService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
