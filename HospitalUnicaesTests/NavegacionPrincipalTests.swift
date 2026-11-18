import Foundation
import Testing
@testable import HospitalUnicaes

/// ViewModels de las pestañas principales (HUNI-42), con datos de ejemplo.
@MainActor
struct NavegacionPrincipalTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = Date(timeIntervalSince1970: 1_792_598_400)

    @Test func miSaludMuestraHistorialYHabitacionDeEjemplo() {
        let viewModel = MiSaludViewModel(hoy: hoy)

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.consultas.map(\.fecha) == viewModel.consultas.map(\.fecha).sorted(by: >))
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }
}
