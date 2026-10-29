import Foundation
import Observation

/// iOS-P4 Solicitar cita. Recepción asigna fecha y doctor; el paciente solo indica preferencias.
@MainActor
@Observable
final class SolicitarCitaViewModel {
    static let especialidades = ["Medicina general", "Alergista", "Emergencia", "No sé"]
    static let franjas = ["Mañana", "Tarde", "Cualquiera"]

    var motivo = ""
    var especialidad = especialidades[0]
    var diaPreferido: Date
    var franja = franjas[2]
    private(set) var motivoError: String?

    init(hoy: Date = Date()) {
        diaPreferido = Formatting.sumarDias(1, a: hoy)
    }

    /// Devuelve la solicitud lista o `nil` (y marca el error) si falta el motivo.
    func enviar() -> SolicitudCita? {
        guard let motivo = motivo.nilIfBlank else {
            motivoError = "Cuéntanos el motivo de la cita."
            return nil
        }
        motivoError = nil
        let dia = "\(Formatting.diaCorto(diaPreferido)) \(Formatting.fechaCorta(diaPreferido))"
        let preferencia = franja == "Cualquiera" ? dia : "\(dia) por la \(franja.lowercased())"
        return SolicitudCita(motivo: motivo, especialidad: especialidad, preferencia: preferencia)
    }
}
