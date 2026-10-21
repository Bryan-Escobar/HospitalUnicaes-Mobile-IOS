import Foundation

/// Roles del sistema que usan la app iOS.
enum UserRole: String, Codable {
    case doctor = "DOCTOR"
    case paciente = "PACIENTE"
}

struct AppUser: Equatable, Identifiable {
    let id: UUID
    let email: String
}
