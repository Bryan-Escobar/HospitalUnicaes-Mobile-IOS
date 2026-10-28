import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct ExpedienteViewModelTests {
    @Test func prohibidoMuestraSinPermiso() async {
        let pacientes = FakePacientesService()
        pacientes.historialResult = .failure(APIError(statusCode: 403, code: "ACCESO_DENEGADO"))
        let viewModel = make(pacientes: pacientes, hospitalizaciones: FakeHospitalizacionesService())
        await viewModel.recargar()
        #expect(viewModel.estado == .sinPermiso)
        #expect(viewModel.historial == nil)
    }

    @Test func hospitalizacionQueFallaNoOcultaElExpediente() async {
        let pacientes = FakePacientesService()
        pacientes.historialResult = .success(DoctorFixtures.historial())
        let hospitalizaciones = FakeHospitalizacionesService()
        hospitalizaciones.result = .failure(APIError(statusCode: 404, code: "RUTA_NO_ENCONTRADA"))
        let viewModel = make(pacientes: pacientes, hospitalizaciones: hospitalizaciones)
        await viewModel.recargar()
        #expect(viewModel.estado == .cargado)
        #expect(viewModel.hospitalizacion == nil)

        hospitalizaciones.result = .success(nil)
        await viewModel.recargar()
        #expect(viewModel.hospitalizacion == nil)
        #expect(viewModel.historial != nil)
    }

    @Test func hospitalizacionActivaSeMuestra() async {
        let pacientes = FakePacientesService()
        pacientes.historialResult = .success(DoctorFixtures.historial())
        let hospitalizaciones = FakeHospitalizacionesService()
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = make(pacientes: pacientes, hospitalizaciones: hospitalizaciones)
        await viewModel.recargar()
        #expect(viewModel.hospitalizacion?.tituloCama == "HAB-204 · Cama A")
    }

    @Test func aplanaYOrdenaLasOrdenes() async {
        let reciente = DoctorFixtures.orden(fecha: Date(timeIntervalSince1970: 2_000))
        let antigua = DoctorFixtures.orden(fecha: Date(timeIntervalSince1970: 1_000))
        var nueva = DoctorFixtures.consulta(citaId: nil, fecha: Date(timeIntervalSince1970: 2_000))
        var vieja = DoctorFixtures.consulta(citaId: nil, fecha: Date(timeIntervalSince1970: 1_000))
        nueva = consulta(nueva, ordenes: [antigua])
        vieja = consulta(vieja, ordenes: [reciente])
        let pacientes = FakePacientesService()
        pacientes.historialResult = .success(DoctorFixtures.historial(consultas: [nueva, vieja]))
        let viewModel = make(pacientes: pacientes, hospitalizaciones: FakeHospitalizacionesService())
        await viewModel.recargar()
        #expect(viewModel.ordenes.map(\.id) == [reciente.id, antigua.id])
    }

    private func make(
        pacientes: FakePacientesService,
        hospitalizaciones: FakeHospitalizacionesService
    ) -> ExpedienteViewModel {
        ExpedienteViewModel(
            pacienteId: UUID(), nombre: "Luis Martínez",
            pacientesService: pacientes, hospitalizacionesService: hospitalizaciones
        )
    }

    private func consulta(_ base: ConsultaDetalle, ordenes: [OrdenLaboratorioResumen]) -> ConsultaDetalle {
        ConsultaDetalle(
            id: base.id, expedienteId: base.expedienteId, paciente: base.paciente, doctor: base.doctor,
            citaId: base.citaId, fecha: base.fecha, motivoConsulta: base.motivoConsulta,
            signosVitales: base.signosVitales, examenFisico: base.examenFisico, notas: base.notas,
            cerradaEn: base.cerradaEn, diagnosticos: base.diagnosticos, recetas: base.recetas,
            ordenesLaboratorio: ordenes
        )
    }
}