import Foundation
import Observation

enum EstadoDetalle: Equatable {
    case cargando
    case completo
    case sinAcceso
    case error
}

enum AccionCita: Equatable {
    case iniciarConsulta
    case verConsulta
    case ninguna
}

/// iOS-D3. El historial aporta edad, documento y alergias; un 403 no es un error de pantalla.
@MainActor
@Observable
final class DetalleCitaViewModel {
    private let citasService: any CitasService
    private let pacientesService: any PacientesService
    private var carga = UUID()

    private(set) var cita: Cita
    private(set) var estado: EstadoDetalle = .cargando
    private(set) var historial: HistorialClinico?
    private(set) var citaNoDisponible = false
    private(set) var errorMessage: String?

    init(cita: Cita, citasService: any CitasService, pacientesService: any PacientesService) {
        self.cita = cita
        self.citasService = citasService
        self.pacientesService = pacientesService
    }

    var accionPrincipal: AccionCita {
        switch cita.estado {
        case .programada, .confirmada: .iniciarConsulta
        case .atendida: .verConsulta
        case .cancelada, .noAsistio, .desconocido: .ninguna
        }
    }

    var consultaDeLaCita: ConsultaDetalle? {
        historial?.consultas.first { $0.citaId == cita.id }
    }

    var alergias: String? {
        guard estado == .completo else { return nil }
        return historial?.expediente.alergias?.nilIfBlank
    }

    var puedeVerExpediente: Bool { estado == .completo }

    var lineaPaciente: String {
        let edad = Formatting.edad(fechaNacimiento: historial?.paciente.fechaNacimiento)
        let documento = historial?.paciente.documentoIdentidad
        return Formatting.unir([edad.map(Formatting.edadTexto), documento.map(Formatting.documento)])
    }

    func recargar() async {
        let token = UUID()
        carga = token
        if historial == nil { estado = .cargando }
        errorMessage = nil
        async let citaTask = capturar { try await self.citasService.cita(id: self.cita.id) }
        async let historialTask = capturar { try await self.pacientesService.historial(pacienteId: self.cita.pacienteId) }
        let citaResultado = await citaTask
        let historialResultado = await historialTask
        guard carga == token else { return }
        if case .success(nil) = citaResultado {
            citaNoDisponible = true
            return
        }
        if case .success(let actualizada?) = citaResultado {
            cita = actualizada
        }
        aplicar(historialResultado)
    }

    private func aplicar(_ resultado: Result<HistorialClinico, Error>) {
        switch resultado {
        case .success(let cargado):
            historial = cargado
            estado = .completo
        case .failure(let error) where Self.esDenegado(error):
            historial = nil
            errorMessage = nil
            estado = .sinAcceso
        case .failure:
            errorMessage = "No se pudo cargar la cita."
            estado = .error
        }
    }

    private static func esDenegado(_ error: Error) -> Bool {
        guard let api = error as? APIError else { return false }
        return api.statusCode == 403 || api.code == "ACCESO_DENEGADO"
    }

    private func capturar<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
