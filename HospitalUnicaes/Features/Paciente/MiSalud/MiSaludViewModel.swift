import Foundation
import Observation

enum MiSaludSegmento: String, CaseIterable, Identifiable {
    case historial
    case laboratorio
    case habitacion

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .historial: "Historial"
        case .laboratorio: "Laboratorio"
        case .habitacion: "Habitación"
        }
    }
}

/// iOS-P5, P7 y P9 Mi salud: historial clínico, laboratorio y habitación del propio paciente.
/// Lo crea la TabView del paciente para que Inicio pueda abrir un segmento concreto.
@MainActor
@Observable
final class MiSaludViewModel {
    var segmento: MiSaludSegmento = .historial
    let alergias: String?
    let consultas: [ConsultaPaciente]
    let resultados: [ResultadoLaboratorio]
    let habitacion: HabitacionPaciente?

    init(hoy: Date = Date()) {
        alergias = PacienteMuestra.alergias
        consultas = PacienteMuestra.consultas(hoy: hoy).sorted { $0.fecha > $1.fecha }
        resultados = PacienteMuestra.resultados(hoy: hoy)
        habitacion = PacienteMuestra.habitacion(hoy: hoy)
    }

    /// Banner de "actualizado ahora" cuando hay un resultado listo.
    var avisoLaboratorio: String? {
        guard let listo = resultados.first(where: { $0.estado == .completado }) else { return nil }
        return "Tu \(listo.examen.lowercased()) ya tiene resultado."
    }
}
