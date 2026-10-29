import Foundation
import Observation

/// iOS-P1 Inicio del paciente. Resume las otras pestañas con datos de ejemplo.
@MainActor
@Observable
final class PacienteInicioViewModel {
    let saludo: String
    let fecha: String
    let proximaCita: CitaPaciente?
    let habitacion: HabitacionPaciente?
    let ultimosResultados: [ResultadoLaboratorio]
    let ambulancia: EstadoAmbulancia
    let aviso: Aviso?

    init(me: Me, hoy: Date = Date(), ambulancia: EstadoAmbulancia = .disponible) {
        saludo = "Hola, \(me.nombres.split(separator: " ").first.map(String.init) ?? me.nombres)"
        fecha = Formatting.fechaLarga(hoy)
        proximaCita = PacienteMuestra.citas(hoy: hoy)
            .filter { $0.fecha >= hoy && ($0.estado == .programada || $0.estado == .confirmada) }
            .min { $0.fecha < $1.fecha }
        habitacion = PacienteMuestra.habitacion(hoy: hoy)
        ultimosResultados = Array(PacienteMuestra.resultados(hoy: hoy).sorted { $0.fecha > $1.fecha }.prefix(2))
        self.ambulancia = ambulancia
        aviso = Aviso(titulo: "Aviso", detalle: "el horario de visitas cambia a 2:00–6:00 p. m. desde el lunes.")
    }

    var puedeSolicitarAmbulancia: Bool { ambulancia == .disponible }
}
