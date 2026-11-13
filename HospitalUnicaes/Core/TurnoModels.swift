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
    var horario: String { "\(horaInicio.prefix(5))–\(horaFin.prefix(5))" }

    var esNocturno: Bool { tipoTurno == "noche" }
}
