import Foundation
import Testing
@testable import HospitalUnicaes

/// Historial clínico propio (HUNI-60) y habitación asignada (HUNI-94) en Mi salud.
@MainActor
struct MiSaludViewModelTests {
    private let historial = FakeHistorialPacienteService()
    private let laboratorio = FakeLaboratorioPacienteService()
    private let hospitalizaciones = FakeHospitalizacionesService()
    private let reciente = Date(timeIntervalSince1970: 1_792_598_400)
    private let antigua = Date(timeIntervalSince1970: 1_788_000_000)

    private func viewModel(pacienteId: UUID? = HistorialFixtures.pacienteId) -> MiSaludViewModel {
        MiSaludViewModel(
            pacienteId: pacienteId, historial: historial, laboratorio: laboratorio, hospitalizaciones: hospitalizaciones
        )
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
        #expect(viewModel.estadoHabitacion == .error("Tu cuenta todavía no tiene un expediente clínico."))
        #expect(historial.pacienteIds.isEmpty)
        #expect(laboratorio.llamadasOrdenes == 0)
        #expect(hospitalizaciones.pacienteIds.isEmpty)
    }

    @Test func cargarSiHaceFaltaSoloCargaUnaVez() async {
        let viewModel = viewModel()

        await viewModel.cargarSiHaceFalta()
        await viewModel.cargarSiHaceFalta()
        #expect(historial.pacienteIds.count == 1)

        await viewModel.recargar()
        #expect(historial.pacienteIds.count == 2)
    }

    // MARK: Habitación asignada (HUNI-94)

    @Test func cargaLaHabitacionYLaCamaAsignadas() async {
        let hospitalizacion = DoctorFixtures.hospitalizacion()
        hospitalizaciones.result = .success(hospitalizacion)
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(hospitalizaciones.pacienteIds == [HistorialFixtures.pacienteId])
        #expect(hospitalizaciones.detalleIds == [hospitalizacion.id])
        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
        #expect(viewModel.habitacion?.cama == "Cama A")
        #expect(viewModel.habitacion?.tipo == .semiprivada)
        #expect(viewModel.habitacion?.planta == "2.ª planta")
        #expect(viewModel.habitacion?.medicoTratante == "Ana Rivas")
        #expect(viewModel.habitacion?.trasladoDesde == nil)
    }

    @Test func muestraLaCamaAnteriorDelUltimoTraslado() async {
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let ingreso = Date(timeIntervalSince1970: 1_792_000_000)
        hospitalizaciones.movimientosResult = .success([
            movimiento(.ingreso, desde: nil, hacia: "HAB-201-A", en: ingreso),
            movimiento(.traslado, desde: "HAB-202-B", hacia: "HAB-204-A", en: ingreso.addingTimeInterval(7_200)),
            movimiento(.traslado, desde: "HAB-201-A", hacia: "HAB-202-B", en: ingreso.addingTimeInterval(3_600)),
        ])
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.habitacion?.trasladoDesde == "HAB-202 · Cama B")
    }

    @Test func sinHospitalizacionActivaQuedaListoYVacio() async {
        hospitalizaciones.result = .success(nil)
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion == nil)
        #expect(hospitalizaciones.detalleIds.isEmpty)
    }

    @Test func siFallaElDetalleMuestraLaHabitacionSinTraslado() async {
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        hospitalizaciones.movimientosResult = .failure(URLError(.timedOut))
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
        #expect(viewModel.habitacion?.trasladoDesde == nil)
    }

    @Test func errorDeLaHabitacionNoAfectaAlHistorialYSeReintenta() async {
        hospitalizaciones.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = viewModel()

        await viewModel.recargar()
        #expect(viewModel.estadoHabitacion == .error("No se pudo cargar tu habitación."))
        #expect(viewModel.habitacion == nil)
        #expect(viewModel.estado == .listo)

        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        await viewModel.recargar()
        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }

    @Test func errorDelHistorialNoAfectaALaHabitacion() async {
        historial.historialResult = .failure(URLError(.timedOut))
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = viewModel()

        await viewModel.recargar()

        #expect(viewModel.estado == .error("No se pudo cargar tu historial clínico."))
        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }

    @Test func errorEnUnaRecargaConservaLaHabitacion() async {
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = viewModel()
        await viewModel.recargar()

        hospitalizaciones.result = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        await viewModel.recargar()

        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }

    @Test func trasDarDeAltaLaRecargaQuitaLaHabitacion() async {
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = viewModel()
        await viewModel.recargar()

        hospitalizaciones.result = .success(nil)
        await viewModel.recargar()

        #expect(viewModel.estadoHabitacion == .listo)
        #expect(viewModel.habitacion == nil)
    }

    private func movimiento(
        _ tipo: TipoMovimientoCama, desde origen: String?, hacia destino: String?, en fecha: Date
    ) -> MovimientoCama {
        MovimientoCama(
            tipo: tipo,
            camaOrigen: origen.map { CamaCodigo(id: UUID(), codigo: $0) },
            camaDestino: destino.map { CamaCodigo(id: UUID(), codigo: $0) },
            createdAt: fecha
        )
    }
}
