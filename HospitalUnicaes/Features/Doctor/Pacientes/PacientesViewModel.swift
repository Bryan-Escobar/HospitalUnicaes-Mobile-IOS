import Foundation
import Observation

/// iOS-D4. La API ya devuelve solo los pacientes que el doctor atiende.
@MainActor
@Observable
final class PacientesViewModel {
    private let service: any PacientesService
    private let debounce: Duration
    private let porPagina: Int
    private var busqueda: Task<Void, Never>?
    private var generacion = 0
    private var totalPaginas = 1
    private var cargandoPagina = false

    var texto = ""
    private(set) var pacientes: [Paciente] = []
    private(set) var pagina = 1
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(
        pacientesService: any PacientesService,
        debounce: Duration = .milliseconds(400),
        porPagina: Int = 50
    ) {
        service = pacientesService
        self.debounce = debounce
        self.porPagina = porPagina
    }

    var buscando: Bool { texto.trimmed.count >= 2 }
    var estaVacio: Bool { !isLoading && errorMessage == nil && pacientes.isEmpty }

    func programarBusqueda() {
        busqueda?.cancel()
        let espera = debounce
        busqueda = Task {
            try? await Task.sleep(for: espera)
            guard !Task.isCancelled else { return }
            await cargarPrimeraPagina()
        }
    }

    func esperarBusqueda() async {
        await busqueda?.value
    }

    func recargar() async { await cargarPrimeraPagina() }

    func cargarPrimeraPagina() async {
        await cargar(pagina: 1, reemplazar: true)
    }

    func cargarSiguienteSiHaceFalta(actual: Paciente) async {
        guard pacientes.last?.id == actual.id, pagina < totalPaginas, !cargandoPagina else { return }
        await cargar(pagina: pagina + 1, reemplazar: false)
    }

    private func cargar(pagina destino: Int, reemplazar: Bool) async {
        if reemplazar { generacion += 1 }
        let generacionActual = generacion
        cargandoPagina = true
        if reemplazar && pacientes.isEmpty { isLoading = true }
        if reemplazar { errorMessage = nil }
        let buscar = texto.trimmed.count >= 2 ? texto.trimmed : nil
        do {
            let page = try await service.pacientes(buscar: buscar, pagina: destino, porPagina: porPagina)
            guard generacionActual == generacion else { return }
            pacientes = reemplazar ? page.items : pacientes + page.items
            pagina = page.paginacion.pagina
            totalPaginas = page.paginacion.totalPaginas
        } catch {
            guard generacionActual == generacion else { return }
            if reemplazar {
                errorMessage = "No se pudo cargar la lista de pacientes."
            }
        }
        if generacionActual == generacion {
            isLoading = false
            cargandoPagina = false
        }
    }
}
