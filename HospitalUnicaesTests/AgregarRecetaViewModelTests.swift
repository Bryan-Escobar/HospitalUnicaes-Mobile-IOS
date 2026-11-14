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

    @Test func sinAlergiasAgregaDirectoYRecortaLosCampos() {
        let viewModel = AgregarRecetaViewModel(alergias: nil)
        viewModel.medicamento = " Loratadina "
        viewModel.dosis = " 10 mg "
        viewModel.frecuencia = "Cada 24 h"
        viewModel.duracion = " 7 días "
        viewModel.indicaciones = "  Con alimentos "

        let receta = viewModel.intentarAgregar()

        #expect(receta?.medicamento == "Loratadina")
        #expect(receta?.dosis == "10 mg")
        #expect(receta?.duracion == "7 días")
        #expect(receta?.indicaciones == "Con alimentos")
        #expect(viewModel.alertaAlergia == nil)
    }

    @Test func frecuenciaEnBlancoNoPermiteAgregar() {
        let viewModel = AgregarRecetaViewModel(alergias: nil)
        viewModel.medicamento = "Loratadina"
        viewModel.dosis = "10 mg"
        viewModel.frecuencia = "  "

        #expect(!viewModel.canAdd)
        #expect(viewModel.intentarAgregar() == nil)
    }

    @Test func cancelarLaAlertaDeAlergiaNoAgregaNada() {
        let viewModel = AgregarRecetaViewModel(alergias: "Penicilina")
        viewModel.medicamento = "Penicilina G benzatínica"
        viewModel.dosis = "1"
        viewModel.frecuencia = "Dosis única"
        #expect(viewModel.intentarAgregar() == nil)
        #expect(viewModel.mensajeAlerta
            == "El paciente tiene registrada alergia a: Penicilina. ¿Agregar Penicilina G benzatínica de todos modos?")

        viewModel.cancelarAlerta()

        #expect(viewModel.alertaAlergia == nil)
        #expect(viewModel.mensajeAlerta == nil)
    }
}
