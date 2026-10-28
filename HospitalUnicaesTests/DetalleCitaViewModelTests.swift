import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct DetalleCitaViewModelTests {
    @Test func accionSegunEstado() {
        for estado in [EstadoCita.programada, .confirmada] {
            let viewModel = make(estado: estado)
            #expect(viewModel.accionPrincipal == .iniciarConsulta)
        }
        #expect(make(estado: .atendida).accionPrincipal == .verConsulta)
        #expect(make(estado: .cancelada).accionPrincipal == .ninguna)
        #expect(make(estado: .noAsistio).accionPrincipal == .ninguna)
    }

    @Test func prohibidoNoEsErrorYEncuentraLaConsulta() async {
        let cita = DoctorFixtures.cita(estado: .atendida)
        let pacientes = FakePacientesService()
        let citas = FakeCitasService()
        citas.citaResult = .success(cita)
        pacientes.historialResult = .failure(APIError(statusCode: 403, code: "ACCESO_DENEGADO"))
        let viewModel = DetalleCitaViewModel(cita: cita, citasService: citas, pacientesService: pacientes)
        await viewModel.recargar()
        #expect(viewModel.estado == .sinAcceso)
        #expect(viewModel.errorMessage == nil)

        let consulta = DoctorFixtures.consulta(citaId: cita.id)
        pacientes.historialResult = .success(DoctorFixtures.historial(consultas: [consulta]))
        await viewModel.recargar()
        #expect(viewModel.consultaDeLaCita?.id == consulta.id)
    }

    @Test func sinAccesoOcultaExpedienteYAlergias() async {
        let cita = DoctorFixtures.cita(estado: .cancelada)
        let citas = FakeCitasService()
        citas.citaResult = .success(cita)
        let pacientes = FakePacientesService()
        pacientes.historialResult = .failure(APIError(statusCode: 403, code: "ACCESO_DENEGADO"))
        let viewModel = DetalleCitaViewModel(cita: cita, citasService: citas, pacientesService: pacientes)
        await viewModel.recargar()
        #expect(!viewModel.puedeVerExpediente)
        #expect(viewModel.alergias == nil)
    }

    @Test func citaQueYaNoEsVisibleNoEstaDisponible() async {
        let citas = FakeCitasService()
        citas.citaResult = .success(nil)
        let viewModel = DetalleCitaViewModel(
            cita: DoctorFixtures.cita(), citasService: citas, pacientesService: FakePacientesService()
        )
        await viewModel.recargar()
        #expect(viewModel.citaNoDisponible)
    }

    private func make(estado: EstadoCita) -> DetalleCitaViewModel {
        DetalleCitaViewModel(
            cita: DoctorFixtures.cita(estado: estado),
            citasService: FakeCitasService(),
            pacientesService: FakePacientesService()
        )
    }
}
