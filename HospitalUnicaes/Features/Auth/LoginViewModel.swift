import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.signIn(email: email, password: password)
        } catch let error as AuthServiceError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "No se pudo iniciar sesión. Verifica tus credenciales."
        }
    }
}
