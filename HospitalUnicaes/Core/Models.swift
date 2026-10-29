import Foundation

/// Roles del sistema (enum `rol_usuario` de la BD, contrato `Rol` de la API).
/// La app iOS solo da acceso a `doctor` y `paciente`; los demás ven "Acceso no disponible".
enum UserRole: String, Codable, CaseIterable {
    case administrador
    case doctor
    case recepcionista
    case paciente

    /// Acepta el valor en cualquier capitalización y trata `asistente` (enum anterior a la
    /// migración `roles_cuatro`) como `recepcionista`.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        if raw == "asistente" {
            self = .recepcionista
        } else if let role = UserRole(rawValue: raw) {
            self = role
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Rol desconocido: \(raw)")
            )
        }
    }

    /// ¿Puede usar la app iOS?
    var usesIOSApp: Bool {
        self == .doctor || self == .paciente
    }

    var displayName: String {
        switch self {
        case .administrador: "Administrador"
        case .doctor: "Doctor"
        case .recepcionista: "Recepcionista/Asistente"
        case .paciente: "Paciente"
        }
    }
}

/// Usuario de Supabase Auth (solo identidad; el perfil viene de `GET /api/auth/me`).
struct AppUser: Equatable, Identifiable {
    let id: UUID
    let email: String
}

/// Respuesta de `GET /api/auth/me` (contrato `Me`, HUNI-38).
struct Me: Codable, Equatable, Identifiable {
    let id: UUID
    let email: String?
    let nombres: String
    let apellidos: String
    let telefono: String?
    let avatarUrl: String?
    let rol: UserRole
    let activo: Bool
    /// Solo si el rol es `paciente`.
    let pacienteId: UUID?
    /// Solo para personal del hospital.
    let personal: PersonalResumen?

    var nombreCompleto: String {
        [nombres, apellidos]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// "Doctor · Alergista", "Paciente".
    var rolYTipo: String {
        guard let personal else { return rol.displayName }
        let detalle = personal.especialidad ?? personal.tipo.nombre
        return detalle.isEmpty ? rol.displayName : "\(rol.displayName) · \(detalle)"
    }
}

struct PersonalResumen: Codable, Equatable {
    struct Tipo: Codable, Equatable {
        let id: UUID
        let nombre: String
    }

    let id: UUID
    let tipo: Tipo
    let especialidad: String?
    let codigoEmpleado: String
}

/// Body de `POST /api/auth/registro` (contrato `RegistroPacienteBody`). El rol no se envía:
/// el registro público siempre crea un paciente.
struct RegistroPacienteRequest: Codable, Equatable {
    var nombres: String
    var apellidos: String
    var email: String
    var password: String
    var documentoIdentidad: String?
    /// `AAAA-MM-DD`.
    var fechaNacimiento: String?
    var telefono: String?
    var contactoEmergencia: String?
    var telefonoEmergencia: String?
    /// Se guarda en `expedientes.alergias` (HUNI-96).
    var alergias: String?
}

/// Respuesta de `GET /health` (contrato `HealthStatus`, HUNI-17). El servidor responde 200
/// aunque la BD esté caída; `database` dice si está disponible.
struct HealthStatus: Decodable, Equatable {
    enum Database: String, Decodable {
        case up
        case down
    }

    let status: String
    /// Instante ISO 8601 del servidor.
    let timestamp: String
    /// Segundos desde que arrancó el proceso.
    let uptime: Double
    let database: Database
}
