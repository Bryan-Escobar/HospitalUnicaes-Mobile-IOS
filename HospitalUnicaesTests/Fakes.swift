import Foundation
@testable import HospitalUnicaes

/// AuthService en memoria con resultados configurables y registro de llamadas.
final class FakeAuthService: AuthService, @unchecked Sendable {
    var storedUser: AppUser?
    var currentUserError: Error?
    var signInResult: Result<AppUser, Error> = .success(AppUser(id: UUID(), email: "doctor@demo.test"))
    var signUpHasSession = true

    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signOutCount = 0
    var resetError: Error?
    private(set) var resetEmails: [String] = []

    func currentUser() async throws -> AppUser? {
        if let currentUserError { throw currentUserError }
        return storedUser
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        signInCalls.append((email, password))
        let user = try signInResult.get()
        storedUser = user
        return user
    }

    func signUp(email: String, password: String) async throws -> Bool { signUpHasSession }

    func signOut() async throws {
        signOutCount += 1
        storedUser = nil
    }

    func resetPassword(email: String) async throws {
        resetEmails.append(email)
        if let resetError { throw resetError }
    }
    func accessToken() async throws -> String? { storedUser == nil ? nil : "token" }
    func sessionEvents() -> AsyncStream<AuthSessionEvent> { AsyncStream { $0.finish() } }
}

/// MeService en memoria.
final class FakeMeService: MeService, @unchecked Sendable {
    var meResult: Result<Me, Error> = .success(.fixture(rol: .doctor))
    var registroResult: Result<Me, Error> = .success(.fixture(rol: .paciente))
    private(set) var fetchCount = 0
    private(set) var registros: [RegistroPacienteRequest] = []

    func fetchMe() async throws -> Me {
        fetchCount += 1
        return try meResult.get()
    }

    func registrar(_ request: RegistroPacienteRequest) async throws -> Me {
        registros.append(request)
        let me = try registroResult.get()
        meResult = .success(me)
        return me
    }
}

extension Me {
    static func fixture(rol: UserRole, especialidad: String? = nil) -> Me {
        Me(
            id: UUID(),
            email: "\(rol.rawValue)@demo.test",
            nombres: "Ana",
            apellidos: "Rivas",
            telefono: nil,
            avatarUrl: nil,
            rol: rol,
            activo: true,
            pacienteId: rol == .paciente ? UUID() : nil,
            personal: rol == .paciente ? nil : PersonalResumen(
                id: UUID(), tipo: .init(id: UUID(), nombre: "Médico"), especialidad: especialidad, codigoEmpleado: "EMP-1"
            )
        )
    }
}
