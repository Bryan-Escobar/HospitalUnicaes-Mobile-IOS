import Foundation

/// Decodifica un enum de texto y cae al valor de reserva si la API manda uno desconocido.
enum EnumDecoding {
    static func value<T: RawRepresentable>(
        _ type: T.Type,
        from decoder: Decoder,
        fallback: T
    ) throws -> T where T.RawValue == String {
        let raw = try decoder.singleValueContainer().decode(String.self)
        return T(rawValue: raw) ?? fallback
    }
}

enum EstadoCita: String, Hashable, Codable {
    case programada
    case confirmada
    case atendida
    case cancelada
    case noAsistio = "no_asistio"
    case desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(EstadoCita.self, from: decoder, fallback: .desconocido)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum Sexo: String, Hashable, Decodable {
    case masculino, femenino, otro, desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(Sexo.self, from: decoder, fallback: .desconocido)
    }

    var nombre: String {
        switch self {
        case .masculino: "Masculino"
        case .femenino: "Femenino"
        case .otro: "Otro"
        case .desconocido: "No registrado"
        }
    }
}

enum EstadoLaboratorio: String, Hashable, Decodable {
    case pendiente
    case enProceso = "en_proceso"
    case completado
    case desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(EstadoLaboratorio.self, from: decoder, fallback: .desconocido)
    }
}

enum PrioridadLaboratorio: String, Hashable, Decodable {
    case normal, urgente, critica, desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(PrioridadLaboratorio.self, from: decoder, fallback: .desconocido)
    }

    var nombre: String {
        switch self {
        case .normal: "Normal"
        case .urgente: "Urgente"
        case .critica: "Crítica"
        case .desconocido: "Normal"
        }
    }
}

enum TipoDiagnostico: String, Hashable, Decodable {
    case principal, secundario, desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(TipoDiagnostico.self, from: decoder, fallback: .desconocido)
    }
}

enum EstadoHospitalizacion: String, Hashable, Decodable {
    case activa, alta, desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(EstadoHospitalizacion.self, from: decoder, fallback: .desconocido)
    }
}

enum TipoHabitacion: String, Hashable, Decodable {
    case vip, semiprivada, desconocido

    init(from decoder: Decoder) throws {
        self = try EnumDecoding.value(TipoHabitacion.self, from: decoder, fallback: .desconocido)
    }

    var nombre: String {
        switch self {
        case .vip: "VIP"
        case .semiprivada: "Semiprivada"
        case .desconocido: "Habitación"
        }
    }
}

protocol NombrePersona {
    var nombres: String { get }
    var apellidos: String { get }
}

extension NombrePersona {
    var nombreCompleto: String {
        [nombres, apellidos]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct PersonaResumen: Decodable, Hashable, NombrePersona {
    let id: UUID
    let nombres: String
    let apellidos: String
}

struct DoctorResumen: Decodable, Hashable, NombrePersona {
    let id: UUID
    let nombres: String
    let apellidos: String
    let especialidad: String?
}

/// Fila de `v_citas`. Las claves van en snake_case: el decoder de PostgREST no convierte claves.
struct Cita: Decodable, Hashable, Identifiable, NombrePersona {
    let id: UUID
    let pacienteId: UUID
    let doctorId: UUID
    let especialidadId: UUID?
    let pacienteNombres: String
    let pacienteApellidos: String
    let doctorNombres: String
    let doctorApellidos: String
    let especialidad: String?
    let fechaHora: Date
    let fechaHoraFin: Date
    let createdAt: Date
    let duracionMinutos: Int
    let motivo: String?
    let estado: EstadoCita

    var nombres: String { pacienteNombres }
    var apellidos: String { pacienteApellidos }
    var pacienteNombre: String { nombreCompleto }

    enum CodingKeys: String, CodingKey {
        case id
        case pacienteId = "paciente_id"
        case doctorId = "doctor_id"
        case especialidadId = "especialidad_id"
        case pacienteNombres = "paciente_nombres"
        case pacienteApellidos = "paciente_apellidos"
        case doctorNombres = "doctor_nombres"
        case doctorApellidos = "doctor_apellidos"
        case especialidad
        case fechaHora = "fecha_hora"
        case fechaHoraFin = "fecha_hora_fin"
        case createdAt = "created_at"
        case duracionMinutos = "duracion_minutos"
        case motivo
        case estado
    }
}

struct Paciente: Decodable, Hashable, Identifiable, NombrePersona {
    let id: UUID
    let perfilId: UUID?
    let nombres: String
    let apellidos: String
    let documentoIdentidad: String?
    let fechaNacimiento: String?
    let sexo: Sexo?
    let telefono: String?
    let direccion: String?
    let contactoEmergencia: String?
    let telefonoEmergencia: String?
    let numeroExpediente: String
    let activo: Bool
    let createdAt: Date
}

struct Expediente: Decodable, Hashable, Identifiable {
    let id: UUID
    let pacienteId: UUID
    let numeroExpediente: String
    let tipoSangre: String?
    let alergias: String?
    let antecedentes: String?
    let enfermedadesCronicas: String?
    let createdAt: Date
    let updatedAt: Date
}

struct Paginacion: Decodable, Hashable {
    let pagina: Int
    let porPagina: Int
    let total: Int
    let totalPaginas: Int
}

struct Pagina<Item: Decodable & Hashable>: Decodable, Hashable {
    let items: [Item]
    let paginacion: Paginacion
}

struct HistorialClinico: Decodable, Hashable {
    let paciente: Paciente
    let expediente: Expediente
    let consultas: [ConsultaDetalle]
}
