import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct AgregarRecetaViewModelTests {
    @Test func exigeMedicamentoDosisYFrecuencia() {
        let viewModel = AgregarRecetaViewModel(alergias: nil)
        #expect(!viewModel.canAdd)
        viewModel.medicamento = "Loratadina"
        viewModel.dosis = "10 mg"
        #expect(!viewModel.canAdd)
        viewModel.frecuencia = "Cada 24 h"
        #expect(viewModel.canAdd)
    }

    @Test func alergiaPideConfirmacion() {
        let viewModel = AgregarRecetaViewModel(alergias: "Penicilina, polen")
        viewModel.medicamento = "Penicilina G benzatínica"
        viewModel.dosis = "1"
        viewModel.frecuencia = "Dosis única"
        #expect(viewModel.intentarAgregar() == nil)
        #expect(viewModel.alertaAlergia == ["Penicilina"])
        let receta = viewModel.confirmarAgregar()
        #expect(receta.medicamento == "Penicilina G benzatínica")
    }
}
