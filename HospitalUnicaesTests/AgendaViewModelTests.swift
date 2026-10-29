import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct AgendaViewModelTests {
    @Test func pideElRangoDelDiaEnElSalvadorYOrdena() async {
        let citas = FakeCitasService()
        let hoy = salvador(2026, 10, 21, 15)
        let viewModel = AgendaViewModel(citasService: citas, hoy: { hoy })
        let tarde = salvador(2026, 10, 21, 16)
        let temprano = salvador(2026, 10, 21, 8)
        citas.citasResult = .success([
            DoctorFixtures.cita(fecha: tarde, nombres: "Tarde"),
            DoctorFixtures.cita(fecha: temprano, nombres: "Temprano"),
        ])

        await viewModel.cargar()

        let desde = salvador(2026, 10, 21)
        let hasta = salvador(2026, 10, 22)
        #expect(citas.rangos.first?.desde == desde)
        #expect(citas.rangos.first?.hasta == hasta)
        #expect(viewModel.citas.map(\.pacienteNombres) == ["Temprano", "Tarde"])
    }

    @Test func vacioErrorYNavegacionDeSemana() async {
        let citas = FakeCitasService()
        let hoy = salvador(2026, 10, 21, 15)
        let viewModel = AgendaViewModel(citasService: citas, hoy: { hoy })
        await viewModel.cargar()
        #expect(viewModel.estaVacio)

        citas.citasResult = .failure(URLError(.notConnectedToInternet))
        await viewModel.cargar()
        #expect(viewModel.errorMessage == "No se pudo cargar la agenda.")

        viewModel.seleccionar(salvador(2026, 10, 28))
        viewModel.irAHoy()
        #expect(Formatting.esMismoDia(viewModel.diaSeleccionado, hoy))

        let semana = viewModel.semana
        #expect(semana.count == 7)
        #expect(Formatting.esMismoDia(semana[0], salvador(2026, 10, 19)))
        #expect(Formatting.esMismoDia(semana[6], salvador(2026, 10, 25)))
        viewModel.semanaAnterior()
        #expect(Formatting.esMismoDia(viewModel.diaSeleccionado, salvador(2026, 10, 14)))
    }
}

private func salvador(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
}