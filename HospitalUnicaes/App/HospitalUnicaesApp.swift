import SwiftUI

@main
struct HospitalUnicaesApp: App {
    @State private var session: SessionViewModel
    @State private var doctorDependencies: DoctorDependencies

    init() {
        #if DEBUG
        // `-HUPreviewEmail doctor@demo.test` abre la app con ese perfil simulado, sin Supabase.
        if let email = UserDefaults.standard.string(forKey: "HUPreviewEmail") {
            let me = MockMeService.me(email: email)
            let state: SessionViewModel.State = me.rol.usesIOSApp ? .signedIn(me) : .accesoNoDisponible(me)
            _session = State(initialValue: .preview(state))
            _doctorDependencies = State(initialValue: .preview)
            return
        }
        #endif
        let supabase = SupabaseClientFactory.make()
        let authService = SupabaseAuthService(client: supabase)
        let apiClient = APIClient { try await authService.accessToken() }
        let meService: MeService = AppConfig.useMockMe
            ? MockMeService(authService: authService)
            : APIMeService(client: apiClient)
        _session = State(initialValue: SessionViewModel(authService: authService, meService: meService))
        _doctorDependencies = State(initialValue: .live(supabase: supabase, api: apiClient))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.doctorDependencies, doctorDependencies)
        }
    }
}
