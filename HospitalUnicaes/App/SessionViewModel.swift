import Foundation
import Observation

/// Estado global de autenticación compartido por toda la app.
@MainActor
@Observable
final class SessionViewModel {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private(set) var state: State = .loading
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func restore() async {
        if let user = await authService.currentUser() {
            state = .signedIn(user)
        } else {
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        let user = try await authService.signIn(email: email, password: password)
        state = .signedIn(user)
    }

    func signOut() async {
        try? await authService.signOut()
        state = .signedOut
    }
}
