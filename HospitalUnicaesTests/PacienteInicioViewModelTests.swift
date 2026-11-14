import Foundation
import Testing
@testable import HospitalUnicaes

final class FakeAvisosService: AvisosService, @unchecked Sendable {
    var result: Result<Aviso?, Error> = .success(nil)
    private(set) var llamadas = 0

    func vigente() async throws -> Aviso? {
        llamadas += 1
        return try result.get()
    }
}

/// iOS-P1 Inicio del paciente con datos reales (HUNI-111).
@MainActor
struct PacienteInicioViewModelTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = salvador(2026, 10, 21, 10)
    let citas = FakeCitasPacienteService()
    let laboratorio = FakeLaboratorioPacienteService()
    let ambulancias = FakeAmbulanciaService()
    let hospitalizaciones = FakeHospitalizacionesService()
    let avisos = FakeAvisosService()
    let me = Me.fixture(rol: .paciente)

    private func make() -> PacienteInicioViewModel {
        PacienteInicioViewModel(
            me: me, citas: citas, laboratorio: laboratorio, ambulancias: ambulancias,
            hospitalizaciones: hospitalizaciones, avisos: avisos, hoy: { hoy }
        )
    }

    private func fallar<T>(_ result: inout Result<T, Error>) {
        result = .failure(APIError(statusCode: 500, code: "HTTP_500"))
    }

    // MARK: Próxima cita

    @Test func laProximaCitaEsLaProgramadaOConfirmadaMasCercana() async {
        citas.citasResult = .success([
            DoctorFixtures.cita(fecha: salvador(2026, 10, 28, 9), estado: .confirmada, motivo: "Lejana"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 22, 9), estado: .programada, motivo: "Cercana"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 21, 16), estado: .cancelada, motivo: "Cancelada"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 14, 9), estado: .programada, motivo: "Pasada"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 14, 11), estado: .atendida, motivo: "Atendida"),
        ])
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.proximaCita?.motivo == "Cercana")
    }

    @Test func sinCitasActivasNoHayProximaCita() async {
        citas.citasResult = .success([
            DoctorFixtures.cita(fecha: salvador(2026, 10, 23, 9), estado: .cancelada),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 14, 9), estado: .atendida),
        ])
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.proximaCita == nil)
        #expect(viewModel.cargado)
        #expect(viewModel.errorParcial == nil)
    }

    // MARK: Resultados, ambulancia, habitación y aviso

    @Test func muestraLosDosUltimosResultados() async {
        laboratorio.ordenesResult = .success([
            LabFixtures.orden(
                id: UUID(), fecha: Date(timeIntervalSince1970: 1_760_000_000),
                examenes: [LabFixtures.examen(nombre: "Antiguo", estado: .completado)]
            ),
            LabFixtures.orden(
                id: UUID(), fecha: Date(timeIntervalSince1970: 1_760_900_000),
                examenes: [
                    LabFixtures.examen(nombre: "Hemograma", estado: .completado),
                    LabFixtures.examen(nombre: "Orina", estado: .pendiente),
                ]
            ),
        ])
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.ultimosResultados.count == 2)
        #expect(!viewModel.ultimosResultados.map(\.nombre).contains("Antiguo"))
    }

    @Test func elEstadoDeLaAmbulanciaVieneDelServicio() async {
        ambulancias.estadoResult = .success(AmbulanciaFixtures.ambulancia(.enServicio))
        let viewModel = make()
        #expect(!viewModel.puedeSolicitarAmbulancia)

        await viewModel.cargar()

        #expect(viewModel.estadoAmbulancia == .enServicio)
        #expect(!viewModel.puedeSolicitarAmbulancia)
        #expect(ambulancias.llamadasEstado == 1)
    }

    @Test func ambulanciaDisponiblePermiteSolicitar() async {
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.puedeSolicitarAmbulancia)
    }

    @Test func sinHospitalizacionNoHayHabitacion() async {
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.habitacion == nil)
    }

    @Test func conHospitalizacionActivaMuestraLaHabitacion() async {
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = make()

        await viewModel.cargar()

        let habitacion = viewModel.habitacion
        #expect(habitacion?.codigo == "HAB-204")
        #expect(habitacion?.cama == "Cama A")
        #expect(habitacion?.planta == "2.ª planta")
        #expect(habitacion?.tipo == .semiprivada)
        #expect(habitacion?.medicoTratante == "Ana Rivas")
    }

    @Test func elAvisoVigenteSeMuestraYSinAvisoNo() async {
        let viewModel = make()
        await viewModel.cargar()
        #expect(viewModel.aviso == nil)

        avisos.result = .success(Aviso(titulo: "Vacunación", detalle: "Sábado de 8:00 a 12:00."))
        await viewModel.cargar()

        #expect(viewModel.aviso?.titulo == "Vacunación")
    }

    // MARK: Carga y errores

    @Test func saludaPorElPrimerNombre() {
        #expect(make().saludo == "Hola, Ana")
    }

    @Test func siTodoFallaMuestraElErrorYReintentarRecupera() async {
        fallar(&citas.citasResult)
        fallar(&laboratorio.ordenesResult)
        fallar(&ambulancias.estadoResult)
        fallar(&hospitalizaciones.result)
        fallar(&avisos.result)
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.errorMessage == PacienteInicioViewModel.mensajeError)
        #expect(!viewModel.cargado)
        #expect(!viewModel.isLoading)

        citas.citasResult = .success([DoctorFixtures.cita(fecha: salvador(2026, 10, 22, 9))])
        laboratorio.ordenesResult = .success([])
        ambulancias.estadoResult = .success(AmbulanciaFixtures.ambulancia(.disponible))
        hospitalizaciones.result = .success(nil)
        avisos.result = .success(nil)
        await viewModel.cargar()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.cargado)
        #expect(viewModel.proximaCita != nil)
    }

    @Test func siFallaUnaSeccionLasDemasSeMuestran() async {
        citas.citasResult = .success([DoctorFixtures.cita(fecha: salvador(2026, 10, 22, 9))])
        fallar(&ambulancias.estadoResult)
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.errorParcial == "No se pudieron cargar: ambulancia.")
        #expect(viewModel.proximaCita != nil)
        #expect(viewModel.estadoAmbulancia == nil)
        #expect(!viewModel.puedeSolicitarAmbulancia)
    }

    @Test func unaRecargaQueFallaConservaLosDatosAnteriores() async {
        citas.citasResult = .success([DoctorFixtures.cita(fecha: salvador(2026, 10, 22, 9), motivo: "Control")])
        avisos.result = .success(Aviso(titulo: "Aviso", detalle: "Detalle"))
        let viewModel = make()
        await viewModel.cargar()

        fallar(&citas.citasResult)
        fallar(&avisos.result)
        fallar(&laboratorio.ordenesResult)
        fallar(&ambulancias.estadoResult)
        fallar(&hospitalizaciones.result)
        await viewModel.cargar()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.errorParcial != nil)
        #expect(viewModel.proximaCita?.motivo == "Control")
        #expect(viewModel.aviso?.titulo == "Aviso")
        #expect(viewModel.estadoAmbulancia == .disponible)
    }

    @Test func unaRecargaExitosaLimpiaElErrorParcial() async {
        fallar(&avisos.result)
        let viewModel = make()
        await viewModel.cargar()
        #expect(viewModel.errorParcial == "No se pudieron cargar: avisos.")

        avisos.result = .success(nil)
        await viewModel.cargar()

        #expect(viewModel.errorParcial == nil)
    }

    @Test func conPacienteSinIdNoPideLaHabitacion() async {
        let sinId = Me(
            id: me.id, email: me.email, nombres: me.nombres, apellidos: me.apellidos, telefono: nil, avatarUrl: nil,
            rol: .paciente, activo: true, pacienteId: nil, personal: nil
        )
        hospitalizaciones.result = .success(DoctorFixtures.hospitalizacion())
        let viewModel = PacienteInicioViewModel(
            me: sinId, citas: citas, laboratorio: laboratorio, ambulancias: ambulancias,
            hospitalizaciones: hospitalizaciones, avisos: avisos, hoy: { hoy }
        )

        await viewModel.cargar()

        #expect(viewModel.habitacion == nil)
        #expect(viewModel.errorParcial == nil)
    }
}

/// HUNI-111: `GET /avisos` con `MockURLProtocol`.
struct APIAvisosServiceTests {
    let base = URL(string: "http://localhost:3000/api")

    private static func respuesta(items: String) -> Data {
        Data(#"""
        {"statusCode":200,"success":true,"message":"OK","data":{"items":[\#(items)],
         "paginacion":{"pagina":1,"por_pagina":1,"total":1,"total_paginas":1}}}
        """#.utf8)
    }

    @Test func devuelveElAvisoVigenteYPideSoloVigentes() async throws {
        let item = #"""
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","titulo":"Jornada de vacunación","contenido":"Este sábado.",
         "es_publico":true,"fecha_publicacion":"2026-11-10T08:00:00-06:00","fecha_expiracion":null,"vigencia":"vigente",
         "autor":{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","nombres":"Admin","apellidos":"Hospital"}}
        """#
        let session = MockURLProtocol.session { _ in (200, Self.respuesta(items: item)) }
        let servicio = APIAvisosService(client: APIClient(baseURL: base, session: session) { "jwt" })

        let aviso = try await servicio.vigente()

        #expect(aviso?.titulo == "Jornada de vacunación")
        #expect(aviso?.detalle == "Este sábado.")
        let request = try #require(MockURLProtocol.requests(of: session).first)
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("http://localhost:3000/api/avisos?"))
        #expect(url.contains("vigencia=vigentes"))
        #expect(url.contains("por_pagina=1"))
    }

    @Test func sinAvisosDevuelveNil() async throws {
        let session = MockURLProtocol.session { _ in (200, Self.respuesta(items: "")) }
        let servicio = APIAvisosService(client: APIClient(baseURL: base, session: session) { "jwt" })

        #expect(try await servicio.vigente() == nil)
    }
}

private func salvador(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
}
