import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct PacientesViewModelTests {
    @Test func unCaracterNoBuscaYDosSi() async {
        let service = FakePacientesService()
        let viewModel = PacientesViewModel(pacientesService: service, debounce: .zero)
        viewModel.texto = "m"
        viewModel.programarBusqueda()
        await viewModel.esperarBusqueda()
        #expect(service.busquedas.last?.buscar == nil)

        viewModel.texto = "mar"
        viewModel.programarBusqueda()
        await viewModel.esperarBusqueda()
        #expect(service.busquedas.last?.buscar == "mar")
    }

    @Test func pideLaPaginaSiguienteAlLlegarAlFinal() async {
        let service = FakePacientesService()
        let primero = DoctorFixtures.paciente(nombres: "Luis")
        let segundo = DoctorFixtures.paciente(nombres: "Elena")
        service.paginas = [
            1: Pagina(items: [primero], paginacion: Paginacion(pagina: 1, porPagina: 50, total: 2, totalPaginas: 2)),
            2: Pagina(items: [segundo], paginacion: Paginacion(pagina: 2, porPagina: 50, total: 2, totalPaginas: 2)),
        ]
        let viewModel = PacientesViewModel(pacientesService: service, debounce: .zero)
        await viewModel.cargarPrimeraPagina()
        await viewModel.cargarSiguienteSiHaceFalta(actual: primero)
        #expect(service.busquedas.map(\.pagina) == [1, 2])
        #expect(viewModel.pacientes.map(\.nombres) == ["Luis", "Elena"])
    }

    @Test func vacioConYSinBusqueda() async {
        let service = FakePacientesService()
        let viewModel = PacientesViewModel(pacientesService: service, debounce: .zero)
        await viewModel.cargarPrimeraPagina()
        #expect(viewModel.estaVacio)
        #expect(!viewModel.buscando)

        viewModel.texto = "zz"
        viewModel.programarBusqueda()
        await viewModel.esperarBusqueda()
        #expect(viewModel.estaVacio)
        #expect(viewModel.buscando)
    }
}
