import Foundation
import Observation

/// Resumen de Inicio del doctor. Datos de ejemplo hasta que existan los endpoints de turnos,
/// laboratorio por médico, ambulancia en tiempo real y avisos.
struct DoctorInicioResumen: Equatable {
    struct Turno: Equatable {
        let horario: String
        let area: String
        let especialidad: String
    }

    struct ProximaCita: Equatable {
        let hora: String
        let paciente: String
        let motivo: String
    }

    struct Laboratorio: Equatable {
        let pendientes: Int
        let enProceso: Int
        let completados: Int
    }

    let turno: Turno?
    let proximaCita: ProximaCita?
    let laboratorio: Laboratorio
    let ambulancia: EstadoAmbulancia
    let aviso: Aviso?

    static let muestra = DoctorInicioResumen(
        turno: Turno(horario: "08:00–14:00", area: "Consulta externa", especialidad: "Alergista"),
        proximaCita: ProximaCita(hora: "10:30", paciente: "Luis Martínez", motivo: "Control de alergia"),
        laboratorio: Laboratorio(pendientes: 2, enProceso: 1, completados: 4),
        ambulancia: .enServicio,
        aviso: Aviso(titulo: "Reunión clínica", detalle: "Viernes 7:00 a. m., auditorio.")
    )
}

/// iOS-D1 Inicio del doctor.
@MainActor
@Observable
final class DoctorInicioViewModel {
    let saludo: String
    let fecha: String
    private(set) var resumen: DoctorInicioResumen

    init(me: Me, resumen: DoctorInicioResumen = .muestra, hoy: Date = Date()) {
        saludo = "Hola, \(me.nombres.split(separator: " ").first.map(String.init) ?? me.nombres)"
        fecha = Formatting.fechaLarga(hoy)
        self.resumen = resumen
    }

    var conteosLaboratorio: [(estado: EstadoLaboratorio, cantidad: Int)] {
        [
            (.pendiente, resumen.laboratorio.pendientes),
            (.enProceso, resumen.laboratorio.enProceso),
            (.completado, resumen.laboratorio.completados),
        ]
    }
}
