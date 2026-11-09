import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct OrdenLaboratorioViewModelTests {
    @Test func cargaExcluyeYExigeSeleccion() async {
        let service = FakeLaboratorioService()
        let bloqueado = UUID()
        service.examenesResult = .success([
            ExamenCatalogo(id: bloqueado, nombre: "Glucosa", categoria: nil, tipoMuestra: nil),
            ExamenCatalogo(id: UUID(), nombre: "Hemograma", categoria: nil, tipoMuestra: nil),
        ])
        let viewModel = OrdenLaboratorioViewModel(service: service, excluidos: [bloqueado])
        await viewModel.cargar()
        #expect(viewModel.examenes.map(\.nombre) == ["Glucosa", "Hemograma"])
        viewModel.seleccionar(viewModel.examenes[0])
        #expect(!viewModel.canCreate)
        viewModel.seleccionar(viewModel.examenes[1])
        #expect(viewModel.canCreate)
        #expect(viewModel.crear()?.examen.nombre == "Hemograma")
    }

    @Test func errorDeCarga() async {
        let service = FakeLaboratorioService()
        service.examenesResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = OrdenLaboratorioViewModel(service: service, excluidos: [])
        await viewModel.cargar()
        #expect(viewModel.errorMessage == "No se pudo cargar el catálogo de exámenes.")
    }
}
