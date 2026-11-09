import Foundation
import Observation

/// iOS-C2 Login: `signIn` con el SDK y luego `/me` (lo hace `SessionViewModel`).
@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isShowingRegistro = false
    var isShowingRecuperar = false

    let session: SessionViewModel
    let isSupabaseConfigured: Bool

    init(session: SessionViewModel, isSupabaseConfigured: Bool = AppConfig.isSupabaseConfigured) {
        self.session = session
        self.isSupabaseConfigured = isSupabaseConfigured
    }

    var canSubmit: Bool {
        !trimmedEmail.isEmpty && !password.isEmpty && !isLoading
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func signIn() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.signIn(email: trimmedEmail, password: password)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Al editar, el error anterior deja de aplicar.
    func clearError() {
        errorMessage = nil
    }
}
