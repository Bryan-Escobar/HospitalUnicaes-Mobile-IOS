import Foundation

struct NuevaConsultaContexto: Equatable, Identifiable {
    let pacienteId: UUID
    let pacienteNombre: String
    let citaId: UUID?
    let citaHora: String?
    let motivo: String?
    let alergias: String?

    var id: String { "\(pacienteId.uuidString)-\(citaId?.uuidString ?? "sin-cita")" }

    var linea: String {
        var partes = [pacienteNombre]
        if let citaHora = citaHora?.nilIfBlank {
            partes.append("Cita \(citaHora)")
        }
        return partes.joined(separator: " · ")
    }
}

struct RecetaBorrador: Identifiable, Equatable {
    let id: UUID
    var medicamento: String
    var dosis: String
    var frecuencia: String
    var duracion: String
    var indicaciones: String
    var enviada = false

    var subtitulo: String {
        Formatting.unir([dosis, frecuencia, duracion.nilIfBlank])
    }
}

struct OrdenBorrador: Identifiable, Equatable {
    let id: UUID
    var examen: ExamenCatalogo
    var indicaciones: String
    var enviada = false
}

enum SalidaConsulta: Equatable {
    case cerrar
    case descartar
    case parcial
}
