import Foundation

/// Estados de la única ambulancia del hospital (`context.md` §3.5).
enum EstadoAmbulancia: String, Hashable {
    case disponible
    case enServicio = "en_servicio"
    case enMantenimiento = "en_mantenimiento"
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
