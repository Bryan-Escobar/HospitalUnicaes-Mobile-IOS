import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct ResultadoArchivoViewModelTests {
    private let service = FakeLaboratorioPacienteService()
    private let archivos = FakeResultadoArchivoService()

    private func viewModel(_ examen: ExamenLaboratorioPaciente) -> ResultadoArchivoViewModel {
        ResultadoArchivoViewModel(examen: examen, service: service, archivos: archivos)
    }

    @Test(arguments: [EstadoLaboratorio.pendiente, .enProceso])
    func sinCompletarNoPideArchivo(estado: EstadoLaboratorio) async {
        let examen = LabFixtures.fila(estado: estado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(viewModel.estado == .sinArchivo)
        #expect(service.llamadasArchivo == 0)
    }

    @Test func completadoSinPDFNoPideArchivo() async {
        let examen = LabFixtures.fila(estado: .completado, tieneArchivo: false)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(viewModel.estado == .sinArchivo)
        #expect(service.llamadasArchivo == 0)
    }

    @Test func completadoConArchivoDescargaUnaVez() async {
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(service.llamadasArchivo == 1)
        #expect(archivos.descargas.count == 1)
        #expect(archivos.descargas.first?.nombre == "resultado-hemograma-completo.pdf")
        guard case .listo(_, let tamano, let miniatura) = viewModel.estado else {
            Issue.record("Se esperaba .listo, llegó \(viewModel.estado)")
            return
        }
        #expect(tamano.contains("bytes") || tamano.contains("KB"))
        #expect(miniatura != nil)
        #expect(viewModel.archivoLocal != nil)
    }

    @Test func enlaceVencidoPideOtraURLUnaVez() async {
        archivos.results = [.failure(ResultadoArchivoError.enlaceVencido), .success(LabFixtures.pdfLocal())]
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(service.llamadasArchivo == 2)
        #expect(viewModel.archivoLocal != nil)
    }

    @Test func enlaceVencidoDosVecesMuestraElMensaje() async {
        archivos.results = [.failure(ResultadoArchivoError.enlaceVencido)]
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(service.llamadasArchivo == 2)
        #expect(viewModel.estado == .error("El enlace caducó, vuelve a abrirlo"))
    }

    @Test func falloMuestraErrorYReintentar() async {
        archivos.results = [.failure(ResultadoArchivoError.fallo), .success(LabFixtures.pdfLocal())]
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)
        #expect(viewModel.estado == .error("No se pudo abrir el PDF."))

        await viewModel.reintentar()
        #expect(viewModel.archivoLocal != nil)
    }

    @Test func dosPrepararSeguidosDescarganUnaVez() async {
        archivos.demora = .milliseconds(50)
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        async let primero: Void = viewModel.preparar(para: examen)
        async let segundo: Void = viewModel.preparar(para: examen)
        _ = await (primero, segundo)

        #expect(archivos.descargas.count == 1)
    }

    @Test func noEncontradoEnLaAPIQuedaSinArchivo() async {
        service.archivoResults = [.failure(APIError(statusCode: 404, code: "NO_ENCONTRADO"))]
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)

        await viewModel.preparar(para: examen)

        #expect(viewModel.estado == .sinArchivo)
        #expect(archivos.descargas.isEmpty)
    }

    @Test func limpiarBorraElArchivoLocal() async {
        let examen = LabFixtures.fila(estado: .completado)
        let viewModel = viewModel(examen)
        await viewModel.preparar(para: examen)
        let local = viewModel.archivoLocal

        viewModel.limpiar()

        #expect(archivos.borrados == [local])
        #expect(viewModel.archivoLocal == nil)
    }
}
