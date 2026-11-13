import Foundation
import Testing
@testable import HospitalUnicaes

/// ViewModels de las pestañas principales (HUNI-42), con datos de ejemplo.
@MainActor
struct NavegacionPrincipalTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = Date(timeIntervalSince1970: 1_792_598_400)

    @Test func inicioDoctorSaludaPorNombreYMuestraConteos() {
        let viewModel = DoctorInicioViewModel(me: .fixture(rol: .doctor), hoy: hoy)

        #expect(viewModel.saludo == "Hola, Ana")
        #expect(viewModel.fecha == "Miércoles 21 de octubre")
        #expect(viewModel.conteosLaboratorio.map(\.cantidad) == [2, 1, 4])
    }

    @Test func inicioPacienteTomaLaCitaProgramadaMasCercana() throws {
        let viewModel = PacienteInicioViewModel(me: .fixture(rol: .paciente), hoy: hoy)

        let cita = try #require(viewModel.proximaCita)
        #expect(cita.fecha > hoy)
        #expect(cita.doctor == "Dra. Ana Rivas")
        #expect(viewModel.ultimosResultados.count == 2)
        #expect(viewModel.puedeSolicitarAmbulancia)
    }

    @Test func citasSeparanProximasDePasadas() {
        let viewModel = CitasPacienteViewModel(hoy: hoy)

        #expect(viewModel.visibles.allSatisfy { $0.fecha >= hoy })
        viewModel.segmento = .pasadas
        #expect(viewModel.visibles.allSatisfy { $0.fecha < hoy })
        #expect(viewModel.visibles.map(\.estado) == [.atendida, .cancelada])
    }

    @Test func solicitudDeCitaPideMotivoYSeAgregaArriba() throws {
        let formulario = SolicitarCitaViewModel(hoy: hoy)
        #expect(formulario.enviar() == nil)
        #expect(formulario.motivoError != nil)

        formulario.motivo = "  Dolor de garganta "
        formulario.franja = "Mañana"
        let solicitud = try #require(formulario.enviar())
        #expect(solicitud.motivo == "Dolor de garganta")
        #expect(solicitud.preferencia.hasSuffix("por la mañana"))

        let citas = CitasPacienteViewModel(hoy: hoy)
        citas.segmento = .pasadas
        citas.agregar(solicitud)
        #expect(citas.solicitudes.first == solicitud)
        #expect(citas.segmento == .proximas)
    }

    @Test func miSaludMuestraHistorialYHabitacionDeEjemplo() {
        let viewModel = MiSaludViewModel(hoy: hoy)

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.consultas.map(\.fecha) == viewModel.consultas.map(\.fecha).sorted(by: >))
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }

    @Test func ocupacionPublicaEsSoloAgregada() {
        let viewModel = InformacionPublicaViewModel()

        #expect(viewModel.ocupacion.map(\.resumen) == ["3/5 ocupadas", "9/12 camas"])
        #expect(viewModel.ocupacion.allSatisfy { $0.progreso <= 1 })
    }
}
