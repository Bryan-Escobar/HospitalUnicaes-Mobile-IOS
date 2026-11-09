import Foundation

/// Estados de la única ambulancia del hospital (`context.md` §3.5). Un valor desconocido
/// se lee como `enServicio`: es el valor seguro porque no deja pedir la ambulancia.
enum EstadoAmbulancia: String, Codable, Hashable, Sendable {
    case disponible
    case enServicio = "en_servicio"
    case enMantenimiento = "en_mantenimiento"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = EstadoAmbulancia(rawValue: value) ?? .enServicio
    }
}

/// Aviso general del hospital (información pública).
struct Aviso: Hashable, Identifiable {
    let id = UUID()
    let titulo: String
    let detalle: String
}

/// Ocupación agregada de una planta: cantidades, nunca nombres (`context.md` §3.4).
struct OcupacionPlanta: Hashable, Identifiable {
    let id = UUID()
    let titulo: String
    let ocupadas: Int
    let total: Int
    let unidad: String

    var progreso: Double { total == 0 ? 0 : Double(ocupadas) / Double(total) }
    var resumen: String { "\(ocupadas)/\(total) \(unidad)" }
}

/// Médico de turno (información pública).
struct MedicoDeTurno: Hashable, Identifiable {
    let id = UUID()
    let nombre: String
    let especialidad: String
    let horario: String
}
