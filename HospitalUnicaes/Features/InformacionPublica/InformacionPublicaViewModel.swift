import Foundation
import Observation

/// iOS-C5 Información pública (HUNI-76): ocupación agregada, médicos de turno ahora y avisos vigentes de
/// `GET /api/publico/estado`. Se abre sin sesión desde el login y con sesión desde Inicio. Solo muestra
/// cantidades y datos del turno, nunca pacientes ni datos personales del personal (`context.md` §3.4).
///
/// Una recarga que falla conserva lo ya cargado y muestra el error en un aviso.
@MainActor
@Observable
final class InformacionPublicaViewModel {
    static let mensajeError = "No se pudo cargar la información del hospital."

    private(set) var ocupacion: [OcupacionPlanta] = []
    private(set) var ocupacionTotal: OcupacionPlanta?
    private(set) var medicosDeTurno: [MedicoDeTurno] = []
    private(set) var avisos: [Aviso] = []
    private(set) var actualizadoEn: Date?
    private(set) var cargado = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: any EstadoPublicoService
    private var carga = UUID()

    init(service: any EstadoPublicoService) {
        self.service = service
    }

    /// "Actualizado a las 10:32".
    var actualizado: String? {
        actualizadoEn.map { "Actualizado a las \(Formatting.hora($0))" }
    }

    /// Error a pantalla completa: nunca se cargó nada.
    var errorSinDatos: String? { cargado ? nil : errorMessage }

    /// Error de una recarga: se muestra en un aviso sobre los datos anteriores.
    var errorRecarga: String? { cargado ? errorMessage : nil }

    var sinMedicos: Bool { cargado && medicosDeTurno.isEmpty }
    var sinAvisos: Bool { cargado && avisos.isEmpty }

    func cargar() async {
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil
        do {
            let estado = try await service.estado()
            guard carga == token else { return }
            aplicar(estado)
            cargado = true
            isLoading = false
        } catch {
            guard carga == token else { return }
            errorMessage = Self.mensaje(para: error)
            isLoading = false
        }
    }

    private func aplicar(_ estado: EstadoPublico) {
        ocupacion = [
            Self.planta("VIP · 3.ª planta", estado.ocupacion.vip),
            Self.planta("Semiprivadas · 2.ª planta", estado.ocupacion.semiprivada),
        ]
        ocupacionTotal = Self.planta("Total del hospital", estado.ocupacion.total)
        medicosDeTurno = estado.medicosDeTurno.map { medico in
            MedicoDeTurno(
                nombre: "\(medico.nombres) \(medico.apellidos)",
                especialidad: medico.especialidad?.nilIfBlank ?? medico.tipo,
                area: medico.area,
                horario: Formatting.horario(medico.horaInicio, medico.horaFin)
            )
        }
        avisos = estado.avisos.map { Aviso(titulo: $0.titulo, detalle: $0.contenido) }
        actualizadoEn = estado.actualizadoEn
    }

    private static func planta(_ titulo: String, _ conteo: EstadoPublico.Conteo) -> OcupacionPlanta {
        OcupacionPlanta(titulo: titulo, ocupadas: conteo.ocupadas, disponibles: conteo.disponibles, total: conteo.total)
    }

    /// Sin sesión no hay "sesión expirada": un 401/403 solo puede ser del servidor.
    private static func mensaje(para error: Error) -> String {
        if let error = error as? URLError { return UserFacingError.message(for: error) }
        return mensajeError
    }
}
