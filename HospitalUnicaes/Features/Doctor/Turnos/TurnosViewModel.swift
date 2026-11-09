import Foundation
import Observation

/// Un día de la semana en "Mis turnos". `horario == nil` es un día sin turno.
struct TurnoDia: Hashable, Identifiable {
    enum Estado: Hashable {
        case terminado
        case enCurso
        case programado
        case sinTurno
    }

    let dia: Date
    let horario: String?
    let area: String?
    let especialidad: String?
    let estado: Estado

    var id: Date { dia }
}

enum TurnosSemana: String, CaseIterable, Identifiable {
    case actual
    case siguiente

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .actual: "Esta semana"
        case .siguiente: "Siguiente"
        }
    }
}

/// iOS-D11 Mis turnos. Genera la semana actual y la siguiente con datos de ejemplo
/// hasta conectar el catálogo de turnos del personal (`context.md` §3.2).
@MainActor
@Observable
final class TurnosViewModel {
    /// Plantilla semanal (lunes = 0): horario, área y especialidad.
    typealias Plantilla = [Int: (horario: String, area: String, especialidad: String)]

    static let plantillaMuestra: Plantilla = [
        0: ("08:00–14:00", "Consulta externa", "Alergista"),
        2: ("08:00–14:00", "Consulta externa", "Alergista"),
        3: ("08:00–14:00", "Consulta externa", "Alergista"),
        4: ("14:00–20:00", "Emergencias (apoyo)", "Emergencia"),
    ]

    var semana: TurnosSemana = .actual
    private let hoy: Date
    private let plantilla: Plantilla

    init(plantilla: Plantilla? = nil, hoy: Date = Date()) {
        self.plantilla = plantilla ?? Self.plantillaMuestra
        self.hoy = hoy
    }

    var turnos: [TurnoDia] {
        let referencia = semana == .actual ? hoy : Formatting.sumarDias(7, a: hoy)
        return Formatting.semana(conteniendo: referencia).enumerated().map { indice, dia in
            guard let turno = plantilla[indice] else {
                return TurnoDia(dia: dia, horario: nil, area: nil, especialidad: nil, estado: .sinTurno)
            }
            return TurnoDia(
                dia: dia,
                horario: turno.horario,
                area: turno.area,
                especialidad: turno.especialidad,
                estado: estado(de: dia)
            )
        }
    }

    /// El turno de hoy, destacado arriba de la lista (solo en la semana actual).
    var turnoDeHoy: TurnoDia? {
        guard semana == .actual else { return nil }
        return turnos.first { $0.estado == .enCurso }
    }

    var restantes: [TurnoDia] {
        turnos.filter { $0 != turnoDeHoy }
    }

    private func estado(de dia: Date) -> TurnoDia.Estado {
        if Formatting.esMismoDia(dia, hoy) { return .enCurso }
        return dia < Formatting.startOfDay(hoy) ? .terminado : .programado
    }
}
