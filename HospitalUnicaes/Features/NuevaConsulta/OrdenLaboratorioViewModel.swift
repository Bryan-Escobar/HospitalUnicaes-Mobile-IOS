import Foundation
import Observation

@MainActor
@Observable
final class OrdenLaboratorioViewModel {
    private let service: any LaboratorioService
    let excluidos: Set<UUID>
    private var pedido = false

    private(set) var examenes: [ExamenCatalogo] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var seleccionado: ExamenCatalogo?
    var indicaciones = ""

    init(service: any LaboratorioService, excluidos: Set<UUID>) {
        self.service = service
        self.excluidos = excluidos
    }

    var canCreate: Bool { seleccionado != nil }

    func cargar() async {
        guard !pedido else { return }
        pedido = true
        isLoading = true
        errorMessage = nil
        do {
            let lista = try await service.examenes()
            examenes = lista.sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending }
            isLoading = false
        } catch {
            pedido = false
            isLoading = false
            errorMessage = "No se pudo cargar el catálogo de exámenes."
        }
    }

    func reintentar() async {
        pedido = false
        await cargar()
    }

    func seleccionar(_ examen: ExamenCatalogo) {
        guard !excluidos.contains(examen.id) else { return }
        seleccionado = examen
    }

    func crear() -> OrdenBorrador? {
        guard let seleccionado else { return nil }
        return OrdenBorrador(
            id: UUID(),
            examen: seleccionado,
            indicaciones: indicaciones.trimmed,
            enviada: false
        )
    }
}
