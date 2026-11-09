import Foundation

/// Estados de una solicitud de ambulancia (`context.md` §3.5). Un valor desconocido se lee
/// como `pendiente` para que la pantalla no se rompa si la API agrega uno nuevo.
enum EstadoSolicitudAmbulancia: String, Codable, Hashable, Sendable {
    case pendiente, despachada
    case enCurso = "en_curso"
    case finalizada, cancelada

    /// Un paciente solo puede tener una solicitud abierta a la vez.
    var estaAbierta: Bool { self == .pendiente || self == .despachada || self == .enCurso }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = EstadoSolicitudAmbulancia(rawValue: value) ?? .pendiente
    }
}

/// Tipo de emergencia de la API. P10 solo ofrece Accidente, Dolor de pecho,
/// Dificultad respiratoria y Otro; el resto lo puede poner recepción.
enum TipoEmergencia: String, Codable, CaseIterable, Hashable, Sendable {
    case accidente, cardiaca, respiratoria, neurologica, obstetrica, intoxicacion, traslado, otra
}

/// La única ambulancia del hospital (`GET /ambulancia`). `solicitudActiva` solo llega
/// cuando el servicio en curso es del propio paciente.
struct Ambulancia: Decodable, Hashable, Sendable {
    struct SolicitudActiva: Decodable, Hashable, Sendable {
        let id: UUID
        let estado: EstadoSolicitudAmbulancia
        let fechaDespacho: Date?
    }

    let id: UUID
    let placa: String
    let estado: EstadoAmbulancia
    let updatedAt: Date
    let solicitudActiva: SolicitudActiva?
}

/// Solicitud de ambulancia del paciente (iOS-P11). Solo los campos que pinta la pantalla.
struct SolicitudAmbulancia: Decodable, Hashable, Identifiable, Sendable {
    let id: UUID
    let estado: EstadoSolicitudAmbulancia
    let tipoEmergencia: TipoEmergencia?
    let descripcionEmergencia: String?
    let direccionOrigen: String?
    let latitud: Double?
    let longitud: Double?
    let precisionM: Int?
    let destino: String?
    let fechaSolicitud: Date
    let fechaDespacho: Date?
    let fechaEnCurso: Date?
    let fechaCierre: Date?
    let notasCierre: String?
    let motivoCancelacion: String?
}

/// Cuerpo de `POST /ambulancia/solicitudes`. El `APIClient` lo pasa a snake_case y el
/// `encode` sintetizado omite las claves `nil` (la API espera número u omitido, no `null`).
struct NuevaSolicitudAmbulancia: Encodable, Equatable, Sendable {
    var direccionOrigen: String?
    var latitud: Double?
    var longitud: Double?
    var precisionM: Int?
    var tipoEmergencia: TipoEmergencia
    var descripcionEmergencia: String?
}

/// Lectura del GPS ya resuelta.
struct Ubicacion: Equatable, Sendable {
    let latitud: Double
    let longitud: Double
    let precisionM: Int
    /// "Col. Escalón, San Salvador" de `CLGeocoder`; puede faltar.
    let direccion: String?
}
