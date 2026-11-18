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

/// Ocupación agregada de un tipo de habitación: cantidades, nunca nombres (`context.md` §3.4).
struct OcupacionPlanta: Hashable, Identifiable {
    let titulo: String
    let ocupadas: Int
    let disponibles: Int
    let total: Int

    var id: String { titulo }
    var progreso: Double { total == 0 ? 0 : min(1, Double(ocupadas) / Double(total)) }
    var resumen: String { "\(ocupadas)/\(total) ocupadas" }
    var detalle: String { Formatting.cantidad(disponibles, singular: "cama disponible", plural: "camas disponibles") }
}

/// Médico de turno en este momento (información pública): nombre, especialidad, área y horario.
struct MedicoDeTurno: Hashable, Identifiable {
    let nombre: String
    let especialidad: String
    let area: String
    let horario: String

    var id: String { "\(nombre)|\(area)|\(horario)" }
}
