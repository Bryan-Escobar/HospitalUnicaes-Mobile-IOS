import Foundation
import Testing
@testable import HospitalUnicaes

final class FakeCitasPacienteService: CitasPacienteService, @unchecked Sendable {
    var citasResult: Result<[Cita], Error> = .success([])
    var solicitudesResult: Result<[SolicitudAtencion], Error> = .success([])
    var especialidadesResult: Result<[Especialidad], Error> = .success([])
    var enviarResult: Result<SolicitudAtencion, Error>?
    private(set) var enviadas: [NuevaSolicitudAtencion] = []

    func citas() async throws -> [Cita] { try citasResult.get() }
    func solicitudes() async throws -> [SolicitudAtencion] { try solicitudesResult.get() }
    func especialidades() async throws -> [Especialidad] { try especialidadesResult.get() }

    func enviar(_ solicitud: NuevaSolicitudAtencion) async throws -> SolicitudAtencion {
        enviadas.append(solicitud)
        if let enviarResult { return try enviarResult.get() }
        return CitasPacienteFixtures.solicitud(solicitud.motivo)
    }
}

enum CitasPacienteFixtures {
    static func solicitud(
        _ motivo: String,
        estado: EstadoSolicitudAtencion = .pendiente,
        respondidaEn: Date? = nil,
        respuesta: String? = nil
    ) -> SolicitudAtencion {
        SolicitudAtencion(
            id: UUID(), motivo: motivo, especialidad: nil, fechaPreferida: "2026-10-22", franja: .manana,
            estado: estado, respuesta: respuesta, respondidaEn: respondidaEn, createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

/// iOS-P2 y P4 con citas de `v_citas` y solicitudes de atención (HUNI-56).
@MainActor
struct CitasPacienteViewModelTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = salvador(2026, 10, 21, 10)

    @Test func separaProximasActivasDePasadas() async {
        let service = FakeCitasPacienteService()
        service.citasResult = .success([
            DoctorFixtures.cita(fecha: salvador(2026, 10, 28, 9), estado: .confirmada, motivo: "Lejana"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 22, 9), estado: .programada, motivo: "Cercana"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 23, 9), estado: .cancelada, motivo: "Cancelada"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 14, 9), estado: .atendida, motivo: "Atendida"),
            DoctorFixtures.cita(fecha: salvador(2026, 10, 7, 9), estado: .noAsistio, motivo: nil),
        ])
        let viewModel = CitasPacienteViewModel(service: service, hoy: { hoy })

        await viewModel.cargar()

        #expect(viewModel.proximas.map(\.motivo) == ["Cercana", "Lejana"])
        viewModel.segmento = .pasadas
        #expect(viewModel.visibles.map(\.motivo) == ["Cancelada", "Atendida", "Consulta"])
        #expect(viewModel.visibles.first?.doctor == "Ana Rivas")
        #expect(viewModel.visibles.first?.especialidad == "Alergista")
    }

    @Test func muestraPendientesYRechazadasRecientes() async {
        let service = FakeCitasPacienteService()
        service.solicitudesResult = .success([
            CitasPacienteFixtures.solicitud("Pendiente"),
            CitasPacienteFixtures.solicitud("Atendida", estado: .atendida, respondidaEn: hoy),
            CitasPacienteFixtures.solicitud("Rechazada", estado: .rechazada, respondidaEn: salvador(2026, 10, 20), respuesta: "Sin cupo"),
            CitasPacienteFixtures.solicitud("Vieja", estado: .rechazada, respondidaEn: salvador(2026, 9, 1)),
        ])
        let viewModel = CitasPacienteViewModel(service: service, hoy: { hoy })

        await viewModel.cargar()

        #expect(viewModel.solicitudes.map(\.motivo) == ["Pendiente", "Rechazada"])
        #expect(viewModel.solicitudes.first?.preferencia == "Jue 22 oct por la mañana")
    }

    @Test func vacioYErrorConReintentar() async {
        let service = FakeCitasPacienteService()
        let viewModel = CitasPacienteViewModel(service: service, hoy: { hoy })
        #expect(!viewModel.estaVacio)

        await viewModel.cargar()
        #expect(viewModel.estaVacio)

        service.citasResult = .failure(URLError(.notConnectedToInternet))
        await viewModel.cargar()
        #expect(viewModel.errorMessage == "No se pudieron cargar tus citas.")
        #expect(!viewModel.estaVacio)
    }

    @Test func laSolicitudEnviadaSubeArriba() async {
        let viewModel = CitasPacienteViewModel(service: FakeCitasPacienteService(), hoy: { hoy })
        viewModel.segmento = .pasadas
        let solicitud = CitasPacienteFixtures.solicitud("Nueva")

        viewModel.agregar(solicitud)

        #expect(viewModel.solicitudes.first == solicitud)
        #expect(viewModel.segmento == .proximas)
    }

    @Test func formularioPideMotivoYEnviaPreferencias() async throws {
        let service = FakeCitasPacienteService()
        let alergologia = Especialidad(id: UUID(), nombre: "Alergología")
        service.especialidadesResult = .success([alergologia])
        let formulario = SolicitarCitaViewModel(service: service, hoy: { hoy })
        await formulario.cargarEspecialidades()
        #expect(formulario.opcionesEspecialidad == ["Alergología", "No sé"])

        #expect(await formulario.enviar() == nil)
        #expect(formulario.motivoError != nil)
        #expect(service.enviadas.isEmpty)

        formulario.motivo = "  Dolor de garganta "
        formulario.especialidad = "Alergología"
        formulario.franja = .manana
        let creada = try #require(await formulario.enviar())

        let enviada = try #require(service.enviadas.first)
        #expect(creada.motivo == "Dolor de garganta")
        #expect(enviada.especialidadId == alergologia.id)
        #expect(enviada.fechaPreferida == "2026-10-22")
        #expect(enviada.franja == .manana)
    }

    @Test func noSeMandaEspecialidadSiNoSabe() async throws {
        let service = FakeCitasPacienteService()
        let formulario = SolicitarCitaViewModel(service: service, hoy: { hoy })
        formulario.motivo = "Control"

        _ = try #require(await formulario.enviar())

        #expect(service.enviadas.first?.especialidadId == nil)
    }

    @Test func muestraElRechazoDeLaBase() async {
        let service = FakeCitasPacienteService()
        service.enviarResult = .failure(APIError(
            statusCode: 422, code: "REGLA_DE_NEGOCIO",
            message: "Ya tienes 3 solicitudes pendientes; espera a que recepción las atienda"
        ))
        let formulario = SolicitarCitaViewModel(service: service, hoy: { hoy })
        formulario.motivo = "Cuarta"

        #expect(await formulario.enviar() == nil)
        #expect(formulario.errorMessage == "Ya tienes 3 solicitudes pendientes; espera a que recepción las atienda")
        #expect(!formulario.isSending)
    }

    @Test func decodificaLaVistaYTraduceErroresDePostgrest() throws {
        let json = """
        {"id":"11111111-1111-4111-8111-000000000001","paciente_id":"22222222-2222-4222-8222-000000000002",
         "paciente_nombres":"Carlos","paciente_apellidos":"Martínez Rivas","motivo":"Revisión de lunares",
         "especialidad_id":null,"especialidad":null,"fecha_preferida":null,"franja":"tarde","estado":"rechazada",
         "cita_id":null,"respuesta":"Sin cirujano","respondida_en":"2026-10-20T15:00:00+00:00",
         "created_at":"2026-10-19T15:00:00.123456+00:00"}
        """
        let solicitud = try SupabaseClientFactory.postgrestDecoder.decode(SolicitudAtencion.self, from: Data(json.utf8))
        #expect(solicitud.estado == .rechazada)
        #expect(solicitud.preferencia == "Cualquier día por la tarde")

        let error = SupabaseCitasPacienteService.mapped(
            code: "PT422", message: "REGLA_DE_NEGOCIO: el día preferido no puede estar en el pasado"
        )
        #expect(error == APIError(statusCode: 422, code: "REGLA_DE_NEGOCIO", message: "El día preferido no puede estar en el pasado"))
    }
}

private func salvador(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
}
