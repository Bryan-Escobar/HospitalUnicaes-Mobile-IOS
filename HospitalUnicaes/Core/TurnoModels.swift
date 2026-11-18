import Foundation

/// Fila de la vista `v_turnos` (HUNI-51). `fecha` es el día en que empieza el turno (`2026-11-13`) y
/// `inicio`/`fin` son instantes reales: el turno de noche termina al día siguiente.
struct TurnoPersonal: Decodable, Hashable, Identifiable {
    let id: UUID
    let personalId: UUID
    let area: String
    let tipoTurno: String
    let fecha: String
    let horaInicio: String
    let horaFin: String
    let inicio: Date
    let fin: Date
    let especialidad: String?
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case id
        case personalId = "personal_id"
        case area
        case tipoTurno = "tipo_turno"
        case fecha
        case horaInicio = "hora_inicio"
        case horaFin = "hora_fin"
        case inicio
        case fin
        case especialidad
        case notas
    }

    /// Día civil (El Salvador) en que empieza.
    var dia: Date? { Formatting.diaCalendario(fecha) }

    /// `07:00–15:00` (Postgres manda `07:00:00`).
    var horario: String { Formatting.horario(horaInicio, horaFin) }

    var esNocturno: Bool { tipoTurno == "noche" }
}

/// Turno de cualquier empleado tal como lo consulta el paciente (HUNI-76). Solo las columnas de `v_turnos`
/// que dicen quién está de turno, dónde y a qué hora: nombre, tipo de personal, especialidad, área y
/// horario. No incluye `notas` ni identificadores del empleado.
struct TurnoDelPersonal: Decodable, Hashable, Identifiable {
    let id: UUID
    let nombres: String
    let apellidos: String
    let tipoPersonal: String
    let especialidad: String?
    let area: String
    let tipoTurno: String
    let fecha: String
    let horaInicio: String
    let horaFin: String
    let inicio: Date
    let fin: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case nombres
        case apellidos
        case tipoPersonal = "tipo_personal"
        case especialidad
        case area
        case tipoTurno = "tipo_turno"
        case fecha
        case horaInicio = "hora_inicio"
        case horaFin = "hora_fin"
        case inicio
        case fin
    }

    /// Las columnas que se piden a `v_turnos`, en el mismo orden que `CodingKeys`.
    static let columnas = CodingKeys.allCases.map(\.rawValue).joined(separator: ",")

    var nombre: String { "\(nombres) \(apellidos)" }
    var horario: String { Formatting.horario(horaInicio, horaFin) }
    var esNocturno: Bool { tipoTurno == "noche" }
}
