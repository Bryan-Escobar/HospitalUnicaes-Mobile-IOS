import Foundation
import Observation

@MainActor
@Observable
final class AgregarRecetaViewModel {
    static let frecuencias = [
        "Cada 4 h", "Cada 6 h", "Cada 8 h", "Cada 12 h", "Cada 24 h", "Dosis única", "Según necesidad",
    ]

    var medicamento = ""
    var dosis = ""
    var frecuencia: String?
    var duracion = ""
    var indicaciones = ""
    private(set) var alertaAlergia: [String]?
    private let alergias: String?

    init(alergias: String?) {
        self.alergias = alergias
    }

    var canAdd: Bool {
        !medicamento.trimmed.isEmpty && !dosis.trimmed.isEmpty && frecuencia?.nilIfBlank != nil
    }

    var mensajeAlerta: String? {
        guard let alertaAlergia, !alertaAlergia.isEmpty else { return nil }
        let lista = alertaAlergia.joined(separator: ", ")
        return "El paciente tiene registrada alergia a: \(lista). ¿Agregar \(medicamento.trimmed) de todos modos?"
    }

    func intentarAgregar() -> RecetaBorrador? {
        guard canAdd else { return nil }
        let coincidencias = AlergiaChecker.coincidencias(medicamento: medicamento, alergias: alergias)
        if !coincidencias.isEmpty {
            alertaAlergia = coincidencias
            return nil
        }
        return borrador()
    }

    func confirmarAgregar() -> RecetaBorrador {
        alertaAlergia = nil
        return borrador()
    }

    func cancelarAlerta() {
        alertaAlergia = nil
    }

    private func borrador() -> RecetaBorrador {
        RecetaBorrador(
            id: UUID(),
            medicamento: medicamento.trimmed,
            dosis: dosis.trimmed,
            frecuencia: frecuencia?.trimmed ?? "",
            duracion: duracion.trimmed,
            indicaciones: indicaciones.trimmed
        )
    }
}
