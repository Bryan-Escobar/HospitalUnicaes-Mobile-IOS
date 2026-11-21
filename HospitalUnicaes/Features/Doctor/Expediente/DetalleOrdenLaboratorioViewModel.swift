import Foundation
import Observation

enum EstadoDetalleOrden: Equatable {
    case cargando
    case cargado
    case sinPermiso
    case error
}

/// Detalle de una orden de laboratorio vista por el médico tratante (`GET /api/laboratorio/ordenes/:id`).
@MainActor
@Observable
final class DetalleOrdenLaboratorioViewModel {
    let ordenId: UUID
    private let laboratorio: any LaboratorioService

    private(set) var estado: EstadoDetalleOrden = .cargando
    private(set) var orden: OrdenLaboratorioPaciente?
    private(set) var errorMessage: String?

    init(ordenId: UUID, laboratorioService: any LaboratorioService) {
        self.ordenId = ordenId
        laboratorio = laboratorioService
    }

    var examenes: [ExamenLaboratorioPaciente] {
        orden?.filas ?? []
    }

    func recargar() async {
        if orden == nil { estado = .cargando }
        errorMessage = nil
        do {
            orden = try await laboratorio.orden(id: ordenId)
            estado = .cargado
        } catch let error as APIError where error.statusCode == 403 || error.code == "ACCESO_DENEGADO" {
            orden = nil
            estado = .sinPermiso
        } catch {
            errorMessage = "No se pudo cargar la orden de laboratorio."
            estado = .error
        }
    }
}
