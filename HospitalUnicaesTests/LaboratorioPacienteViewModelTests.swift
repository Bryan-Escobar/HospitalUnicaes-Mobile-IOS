import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct LaboratorioPacienteViewModelTests {
    private let service = FakeLaboratorioPacienteService()
    private let realtime = FakeLaboratorioRealtime()

    private func viewModel(respaldo: Duration = .seconds(60)) -> LaboratorioPacienteViewModel {
        LaboratorioPacienteViewModel(service: service, realtime: realtime, intervaloRespaldo: respaldo)
    }

    private func ordenes(_ estado: EstadoLaboratorio) -> [OrdenLaboratorioPaciente] {
        [LabFixtures.orden(examenes: [LabFixtures.examen(estado: estado)])]
    }

    /// Arranca `escuchar()` y espera a que termine la primera carga.
    private func escuchando(_ viewModel: LaboratorioPacienteViewModel) async -> Task<Void, Never> {
        let task = Task { await viewModel.escuchar() }
        await esperar { viewModel.estado != .cargando && realtime.suscripciones == 1 }
        return task
    }

    @Test func escucharCargaLasFilas() async {
        service.ordenesResult = .success(ordenes(.pendiente))
        let viewModel = viewModel()

        let task = await escuchando(viewModel)
        defer { task.cancel() }

        #expect(viewModel.estado == .listo)
        #expect(viewModel.examenes.map(\.nombre) == ["Hemograma completo"])
        #expect(viewModel.aviso == nil)
    }

    @Test func sinOrdenesQuedaListoYVacio() async {
        let viewModel = viewModel()
        await viewModel.recargar()

        #expect(viewModel.estado == .listo)
        #expect(viewModel.examenes.isEmpty)
    }

    @Test func errorEnLaPrimeraCargaYReintentoExitoso() async {
        service.ordenesResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = viewModel()

        await viewModel.recargar()
        #expect(viewModel.estado == .error("No se pudieron cargar tus exámenes."))

        service.ordenesResult = .success(ordenes(.pendiente))
        await viewModel.recargar()
        #expect(viewModel.estado == .listo)
        #expect(viewModel.examenes.count == 1)
    }

    @Test func errorEnUnaRecargaConservaLosDatos() async {
        service.ordenesResult = .success(ordenes(.pendiente))
        let viewModel = viewModel()
        let task = await escuchando(viewModel)
        defer { task.cancel() }
        realtime.enviar(.conexion(.live))
        await esperar { viewModel.conexion == .live }

        service.ordenesResult = .failure(URLError(.timedOut))
        await viewModel.recargar()

        #expect(viewModel.estado == .listo)
        #expect(viewModel.examenes.count == 1)
        #expect(viewModel.conexion == .reconnecting)
    }

    @Test func eventoConExamenCompletadoActualizaYAvisa() async {
        service.ordenesResult = .success(ordenes(.enProceso))
        let viewModel = viewModel()
        let task = await escuchando(viewModel)
        defer { task.cancel() }

        service.ordenesResult = .success(ordenes(.completado))
        realtime.enviar(.examenCambio)
        await esperar { viewModel.aviso != nil }

        #expect(viewModel.examenes.first?.estado == .completado)
        #expect(viewModel.aviso?.id == LabFixtures.hemogramaId)
        #expect(viewModel.textoAviso == "Actualizado ahora: tu hemograma completo ya tiene resultado.")
        #expect(viewModel.examen(id: LabFixtures.hemogramaId)?.estado == .completado)

        viewModel.descartarAviso()
        #expect(viewModel.aviso == nil)
        #expect(viewModel.textoAviso == nil)
    }

    @Test func primeraCargaConCompletadosNoAvisa() async {
        service.ordenesResult = .success(ordenes(.completado))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.examenes.first?.estado == .completado)
        #expect(viewModel.aviso == nil)
    }

    @Test func avisaElCompletadoMasReciente() async {
        let otro = UUID()
        service.ordenesResult = .success([LabFixtures.orden(examenes: [
            LabFixtures.examen(estado: .enProceso),
            LabFixtures.examen(id: otro, nombre: "Química sanguínea", estado: .enProceso),
        ])])
        let viewModel = viewModel()
        await viewModel.recargar()

        service.ordenesResult = .success([LabFixtures.orden(examenes: [
            LabFixtures.examen(estado: .completado, completado: Date(timeIntervalSince1970: 100)),
            LabFixtures.examen(id: otro, nombre: "Química sanguínea", estado: .completado, completado: Date(timeIntervalSince1970: 200)),
        ])])
        await viewModel.recargar()

        #expect(viewModel.aviso?.id == otro)
    }

    @Test func recargasSeguidasSeCoalescen() async {
        service.ordenesResult = .success(ordenes(.pendiente))
        service.demora = .milliseconds(100)
        let viewModel = viewModel()

        async let primera: Void = viewModel.recargar()
        async let segunda: Void = viewModel.recargar()
        async let tercera: Void = viewModel.recargar()
        async let cuarta: Void = viewModel.recargar()
        _ = await (primera, segunda, tercera, cuarta)

        #expect(service.llamadasOrdenes <= 2)
        #expect(viewModel.estado == .listo)
    }

    @Test func respaldoRecargaMientrasNoEstaEnVivo() async {
        service.ordenesResult = .success(ordenes(.pendiente))
        let viewModel = viewModel(respaldo: .milliseconds(20))
        let task = await escuchando(viewModel)
        defer { task.cancel() }

        realtime.enviar(.conexion(.reconnecting))
        await esperar { service.llamadasOrdenes >= 3 }
        #expect(viewModel.conexion == .reconnecting)

        realtime.enviar(.conexion(.live))
        await esperar { viewModel.conexion == .live }
        try? await Task.sleep(for: .milliseconds(40))
        let llamadas = service.llamadasOrdenes
        try? await Task.sleep(for: .milliseconds(100))
        #expect(service.llamadasOrdenes == llamadas)
    }
}

/// Espera (hasta ~2 s) a que se cumpla una condición que cambia en otra tarea.
@MainActor
func esperar(_ condicion: @MainActor () -> Bool) async {
    for _ in 0..<200 where !condicion() {
        try? await Task.sleep(for: .milliseconds(10))
    }
}
