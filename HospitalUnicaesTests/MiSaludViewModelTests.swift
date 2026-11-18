import Foundation
import Testing
@testable import HospitalUnicaes

/// Historial clínico propio en Mi salud (HUNI-60).
@MainActor
struct MiSaludViewModelTests {
    private let historial = FakeHistorialPacienteService()
    private let laboratorio = FakeLaboratorioPacienteService()
    private let reciente = Date(timeIntervalSince1970: 1_792_598_400)
    private let antigua = Date(timeIntervalSince1970: 1_788_000_000)

    private func viewModel(pacienteId: UUID? = HistorialFixtures.pacienteId) -> MiSaludViewModel {
        MiSaludViewModel(pacienteId: pacienteId, historial: historial, laboratorio: laboratorio)
    }

    @Test func empiezaEnHistorialCargando() {
        let viewModel = viewModel()

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.estado == .cargando)
        #expect(viewModel.consultas.isEmpty)
        #expect(historial.pacienteIds.isEmpty)
    }

    @Test func cargaAlergiasYConsultasMasRecientesPrimero() async {
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: antigua, diagnostico: "Dermatitis de contacto"),
            HistorialFixtures.consulta(fecha: reciente, diagnostico: "Rinitis alérgica"),
        ]))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(historial.pacienteIds == [HistorialFixtures.pacienteId])
        #expect(viewModel.estado == .listo)
        #expect(viewModel.alergias == "Penicilina")
        #expect(viewModel.consultas.map(\.diagnostico) == ["Rinitis alérgica", "Dermatitis de contacto"])
        #expect(viewModel.consultas.map(\.fecha) == [reciente, antigua])
        #expect(viewModel.consultas[0].doctor == "Ana Rivas")
        #expect(viewModel.consultas[0].detalleDoctor == "Ana Rivas · Alergología")
    }

    @Test func sinDiagnosticoUsaElMotivo() async {
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: reciente, diagnostico: nil, motivo: "Dolor de cabeza"),
        ]))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.consultas.map(\.diagnostico) == ["Dolor de cabeza"])
    }

    @Test func consultaTraeRecetasYLosExamenesDeSusOrdenes() async throws {
        let otraOrden = UUID()
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(
                fecha: reciente,
                recetas: [
                    HistorialFixtures.receta(indicaciones: "Tomar con comida", [
                        HistorialFixtures.medicamento("Amoxicilina", dosis: "500 mg", frecuencia: "Cada 8 h", duracion: "7 días"),
                        HistorialFixtures.medicamento("Loratadina 10 mg"),
                    ]),
                ],
                ordenes: [LabFixtures.ordenId]
            ),
        ]))
        laboratorio.ordenesResult = .success([
            LabFixtures.orden(examenes: [
                LabFixtures.examen(estado: .completado),
                LabFixtures.examen(id: LabFixtures.quimicaId, nombre: "Química sanguínea", estado: .pendiente),
            ]),
            LabFixtures.orden(id: otraOrden, examenes: [
                LabFixtures.examen(id: UUID(), nombre: "Examen general de orina", estado: .pendiente),
            ]),
        ])
        let viewModel = viewModel()

        await viewModel.recargar()

        let consulta = try #require(viewModel.consultas.first)
        #expect(consulta.recetas.map(\.medicamento) == ["Amoxicilina", "Loratadina 10 mg"])
        #expect(consulta.recetas.map(\.indicacion) == [
            "500 mg · Cada 8 h · 7 días · Tomar con comida",
            "Tomar con comida",
        ])
        #expect(consulta.ordenes?.map(\.nombre) == ["Hemograma completo", "Química sanguínea"])
        #expect(consulta.ordenes?.map(\.estado) == [.completado, .pendiente])
        #expect(consulta.ordenes?.allSatisfy { $0.ordenId == LabFixtures.ordenId } == true)
    }

    @Test func consultaSinOrdenesTieneListaVacia() async {
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: reciente),
        ]))
        laboratorio.ordenesResult = .success([LabFixtures.orden(examenes: [LabFixtures.examen(estado: .pendiente)])])
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.consultas.first?.ordenes == [])
        #expect(viewModel.consultas.first?.recetas == [])
    }

    @Test func siFallanLasOrdenesElHistorialSeMuestraIgual() async {
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: reciente, ordenes: [LabFixtures.ordenId]),
        ]))
        laboratorio.ordenesResult = .failure(URLError(.timedOut))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.estado == .listo)
        #expect(viewModel.consultas.count == 1)
        #expect(viewModel.consultas.first?.ordenes == nil)
    }

    @Test func sinConsultasNiAlergiasQuedaListoYVacio() async {
        historial.historialResult = .success(HistorialFixtures.historial(alergias: "  "))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.estado == .listo)
        #expect(viewModel.alergias == nil)
        #expect(viewModel.consultas.isEmpty)
    }

    @Test func errorEnLaPrimeraCargaYReintentoExitoso() async {
        historial.historialResult = .failure(URLError(.notConnectedToInternet))
        let viewModel = viewModel()

        await viewModel.recargar()
        #expect(viewModel.estado == .error("No se pudo cargar tu historial clínico."))

        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: reciente),
        ]))
        await viewModel.recargar()
        #expect(viewModel.estado == .listo)
        #expect(viewModel.consultas.count == 1)
    }

    @Test func errorEnUnaRecargaConservaLosDatos() async {
        historial.historialResult = .success(HistorialFixtures.historial(consultas: [
            HistorialFixtures.consulta(fecha: reciente),
        ]))
        let viewModel = viewModel()
        await viewModel.recargar()

        historial.historialResult = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        await viewModel.recargar()

        #expect(viewModel.estado == .listo)
        #expect(viewModel.consultas.count == 1)
        #expect(viewModel.alergias == "Penicilina")
    }

    @Test func sinPacienteAsociadoNoLlamaALaAPI() async {
        let viewModel = viewModel(pacienteId: nil)

        await viewModel.recargar()

        #expect(viewModel.estado == .error("Tu cuenta todavía no tiene un expediente clínico."))
        #expect(historial.pacienteIds.isEmpty)
        #expect(laboratorio.llamadasOrdenes == 0)
    }

    @Test func cargarSiHaceFaltaSoloCargaUnaVez() async {
        let viewModel = viewModel()

        await viewModel.cargarSiHaceFalta()
        await viewModel.cargarSiHaceFalta()
        #expect(historial.pacienteIds.count == 1)

        await viewModel.recargar()
        #expect(historial.pacienteIds.count == 2)
    }

    @Test func laHabitacionSigueSiendoDeEjemploHastaHUNI94() {
        #expect(viewModel().habitacion?.codigo == "HAB-204")
    }
}
