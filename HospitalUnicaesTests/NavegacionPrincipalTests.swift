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
