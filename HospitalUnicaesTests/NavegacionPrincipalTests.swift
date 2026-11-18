import Foundation
import Testing
@testable import HospitalUnicaes

/// ViewModels de las pestañas principales (HUNI-42).
@MainActor
struct NavegacionPrincipalTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = Date(timeIntervalSince1970: 1_792_598_400)

    @Test func miSaludAbreEnHistorialConHabitacionDeEjemplo() {
        let viewModel = MiSaludViewModel(
            pacienteId: UUID(),
            historial: FakeHistorialPacienteService(),
            laboratorio: FakeLaboratorioPacienteService(),
            hoy: hoy
        )

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }
}
