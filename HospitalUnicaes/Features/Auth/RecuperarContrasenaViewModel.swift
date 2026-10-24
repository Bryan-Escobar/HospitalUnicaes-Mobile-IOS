import Foundation
import Observation

/// iOS-C4 Recuperar contraseña. Por privacidad la respuesta es la misma exista o no el correo.
@MainActor
@Observable
final class RecuperarContrasenaViewModel {
    var email = ""
    private(set) var isLoading = false
    private(set) var didSend = false
    private(set) var errorMessage: String?

    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        trimmedEmail.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil && !isLoading
    }

    func send() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await session.resetPassword(email: trimmedEmail)
            didSend = true
        } catch is URLError {
            errorMessage = UserFacingError.message(for: URLError(.notConnectedToInternet))
        } catch let error as AuthServiceError where error == .missingConfiguration {
            errorMessage = error.localizedDescription
        } catch {
            // Cualquier otra respuesta (correo inexistente, límite de envíos) se muestra igual que el éxito.
            didSend = true
        }
    }
}
