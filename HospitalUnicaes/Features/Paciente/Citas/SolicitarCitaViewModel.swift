import Foundation
import Observation

/// iOS-P4 Solicitar atención (HUNI-56). El paciente cuenta el motivo y sus preferencias; recepción asigna
/// fecha y doctor desde su bandeja. Las reglas (motivo, día no pasado, máximo 3 pendientes) las valida la base.
@MainActor
@Observable
final class SolicitarCitaViewModel {
    /// "No sé" no manda especialidad.
    static let sinEspecialidad = "No sé"

    private let service: any CitasPacienteService
    private let hoy: () -> Date

    var motivo = ""
    var especialidad = SolicitarCitaViewModel.sinEspecialidad
    var diaPreferido: Date
    var franja: FranjaHoraria = .cualquiera
    private(set) var especialidades: [Especialidad] = []
    private(set) var motivoError: String?
    private(set) var errorMessage: String?
    private(set) var isSending = false

    init(service: any CitasPacienteService, hoy: @escaping () -> Date = Date.init) {
        self.service = service
        self.hoy = hoy
        diaPreferido = Formatting.sumarDias(1, a: hoy())
    }

    var opcionesEspecialidad: [String] {
        especialidades.map(\.nombre) + [Self.sinEspecialidad]
    }

    /// Si el catálogo no carga, el formulario sigue con "No sé".
    func cargarEspecialidades() async {
        guard especialidades.isEmpty else { return }
        especialidades = (try? await service.especialidades()) ?? []
    }

    /// Devuelve la solicitud creada o `nil` (con el error a la vista) si falta el motivo o la base la rechaza.
    func enviar() async -> SolicitudAtencion? {
        guard !isSending else { return nil }
        guard let motivo = motivo.nilIfBlank, motivo.count >= 3 else {
            motivoError = "Cuéntanos el motivo de la atención (mínimo 3 letras)."
            return nil
        }
        motivoError = nil
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        let solicitud = NuevaSolicitudAtencion(
            motivo: motivo,
            especialidadId: especialidades.first { $0.nombre == especialidad }?.id,
            fechaPreferida: Formatting.diaISO(max(diaPreferido, Formatting.startOfDay(hoy()))),
            franja: franja
        )
        do {
            return try await service.enviar(solicitud)
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }
}
