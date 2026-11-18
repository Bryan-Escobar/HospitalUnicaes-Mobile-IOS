import Foundation
import Testing
@testable import HospitalUnicaes

/// ViewModels de las pestañas principales (HUNI-42).
@MainActor
struct NavegacionPrincipalTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = Date(timeIntervalSince1970: 1_792_598_400)

    @Test func miSaludAbreEnHistorialSinHabitacionHastaCargar() {
        let viewModel = MiSaludViewModel(
            pacienteId: UUID(),
            historial: FakeHistorialPacienteService(),
            laboratorio: FakeLaboratorioPacienteService(),
            hospitalizaciones: FakeHospitalizacionesService()
        )

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.estadoHabitacion == .cargando)
        #expect(viewModel.habitacion == nil)
    }

    @Test func ocupacionPublicaEsSoloAgregada() {
        let viewModel = InformacionPublicaViewModel()

        #expect(viewModel.ocupacion.map(\.resumen) == ["3/5 ocupadas", "9/12 camas"])
        #expect(viewModel.ocupacion.allSatisfy { $0.progreso <= 1 })
    }
}
