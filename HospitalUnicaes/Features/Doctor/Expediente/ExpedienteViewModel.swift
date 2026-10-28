import Foundation
import Observation

enum EstadoExpediente: Equatable {
    case cargando
    case cargado
    case sinPermiso
    case error
}

enum ExpedienteSegmento: String, CaseIterable, Identifiable {
    case consultas
    case laboratorio
    case datos

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .consultas: "Consultas"
        case .laboratorio: "Laboratorio"
        case .datos: "Datos"
        }
    }
}

struct OrdenVisible: Identifiable, Equatable {
    let id: UUID
    let fecha: Date
    let totalExamenes: Int
    let prioridad: PrioridadLaboratorio
    let estado: EstadoLaboratorio
}

/// iOS-D5. Historial y hospitalización se piden en paralelo; la habitación nunca tumba la pantalla.
@MainActor
@Observable
final class ExpedienteViewModel {
    let pacienteId: UUID
    let nombre: String
    private let pacientes: any PacientesService
    private let hospitalizaciones: any HospitalizacionesService

    private(set) var estado: EstadoExpediente = .cargando
    private(set) var historial: HistorialClinico?
    private(set) var hospitalizacion: Hospitalizacion?
    private(set) var errorMessage: String?
    var segmento: ExpedienteSegmento = .consultas

    init(
        pacienteId: UUID,
        nombre: String,
        pacientesService: any PacientesService,
        hospitalizacionesService: any HospitalizacionesService
    ) {
        self.pacienteId = pacienteId
        self.nombre = nombre
        pacientes = pacientesService
        hospitalizaciones = hospitalizacionesService
    }

    var ordenes: [OrdenVisible] {
        let ordenadas = (historial?.consultas.flatMap(\.ordenesLaboratorio) ?? [])
            .sorted { $0.fechaSolicitud > $1.fechaSolicitud }
        return ordenadas.map {
            OrdenVisible(
                id: $0.id,
                fecha: $0.fechaSolicitud,
                totalExamenes: $0.totalExamenes,
                prioridad: $0.prioridad,
                estado: $0.estado
            )
        }
    }

    func recargar() async {
        if historial == nil { estado = .cargando }
        errorMessage = nil
        async let historialTask = capturar { try await self.pacientes.historial(pacienteId: self.pacienteId) }
        async let hospTask = capturar { try await self.hospitalizaciones.activa(pacienteId: self.pacienteId) }
        let historialResultado = await historialTask
        let hospResultado = await hospTask
        switch historialResultado {
        case .success(let cargado):
            historial = cargado
            hospitalizacion = try? hospResultado.get()
            estado = .cargado
        case .failure(let error) where Self.esDenegado(error):
            historial = nil
            hospitalizacion = nil
            estado = .sinPermiso
        case .failure:
            hospitalizacion = nil
            errorMessage = "No se pudo cargar el expediente."
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
