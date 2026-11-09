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

/// iOS-P5 y P9 Mi salud: historial clínico y habitación del propio paciente (datos de ejemplo
/// hasta HUNI-60 y HUNI-94). El laboratorio (iOS-P7) vive en `LaboratorioPacienteViewModel`.
/// Lo crea la TabView del paciente para que Inicio pueda abrir un segmento concreto.
@MainActor
@Observable
final class MiSaludViewModel {
    var segmento: MiSaludSegmento = .historial
    let alergias: String?
    let consultas: [ConsultaPaciente]
    let habitacion: HabitacionPaciente?

    init(hoy: Date = Date()) {
        alergias = PacienteMuestra.alergias
        consultas = PacienteMuestra.consultas(hoy: hoy).sorted { $0.fecha > $1.fecha }
        habitacion = PacienteMuestra.habitacion(hoy: hoy)
    }
}
