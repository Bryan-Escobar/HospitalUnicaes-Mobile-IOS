import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct DetalleOrdenLaboratorioViewModelTests {
    @Test func cargaLaOrdenYAplanaExamenesOrdenadosPorNombre() async {
        let service = FakeLaboratorioService()
        let orden = LabFixtures.orden(examenes: [
            LabFixtures.examen(id: LabFixtures.quimicaId, nombre: "Química sanguínea", estado: .enProceso),
            LabFixtures.examen(id: LabFixtures.hemogramaId, nombre: "Hemograma completo", estado: .completado),
        ])
        service.ordenResult = .success(orden)

        let viewModel = DetalleOrdenLaboratorioViewModel(ordenId: orden.id, laboratorioService: service)
        await viewModel.recargar()

        #expect(viewModel.estado == .cargado)
        #expect(viewModel.orden?.id == orden.id)
        #expect(service.ordenesSolicitadas == [orden.id])
        #expect(viewModel.examenes.map(\.nombre) == ["Hemograma completo", "Química sanguínea"])
        #expect(viewModel.examenes.map(\.estado) == [.completado, .enProceso])
    }

    @Test func prohibidoMuestraSinPermiso() async {
        let service = FakeLaboratorioService()
        service.ordenResult = .failure(APIError(statusCode: 403, code: "ACCESO_DENEGADO"))

        let viewModel = DetalleOrdenLaboratorioViewModel(ordenId: LabFixtures.ordenId, laboratorioService: service)
        await viewModel.recargar()

        #expect(viewModel.estado == .sinPermiso)
        #expect(viewModel.orden == nil)
    }

    @Test func errorYReintentoRecuperaLaOrden() async {
        let service = FakeLaboratorioService()
        service.ordenResult = .failure(APIError(statusCode: 500, code: "ERROR_INTERNO"))

        let viewModel = DetalleOrdenLaboratorioViewModel(ordenId: LabFixtures.ordenId, laboratorioService: service)
        await viewModel.recargar()

        #expect(viewModel.estado == .error)
        #expect(viewModel.errorMessage != nil)

        service.ordenResult = .success(LabFixtures.orden(examenes: [
            LabFixtures.examen(nombre: "Hemograma completo", estado: .completado),
        ]))
        await viewModel.recargar()

        #expect(viewModel.estado == .cargado)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.examenes.count == 1)
    }
}
