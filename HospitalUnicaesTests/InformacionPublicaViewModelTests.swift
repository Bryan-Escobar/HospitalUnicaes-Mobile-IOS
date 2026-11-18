import Foundation
import Testing
@testable import HospitalUnicaes

final class FakeEstadoPublicoService: EstadoPublicoService, @unchecked Sendable {
    var result: Result<EstadoPublico, Error> = .success(InformacionPublicaFixtures.estado())
    private(set) var llamadas = 0

    func estado() async throws -> EstadoPublico {
        llamadas += 1
        return try result.get()
    }
}

enum InformacionPublicaFixtures {
    static func estado(
        medicos: [EstadoPublico.Medico] = [medico()],
        avisos: [EstadoPublico.AvisoPublico] = [aviso()]
    ) -> EstadoPublico {
        EstadoPublico(
            ocupacion: .init(
                vip: .init(ocupadas: 3, disponibles: 2, total: 5),
                semiprivada: .init(ocupadas: 11, disponibles: 1, total: 12),
                total: .init(ocupadas: 14, disponibles: 3, total: 17)
            ),
            medicosDeTurno: medicos,
            avisos: avisos,
            actualizadoEn: Date(timeIntervalSince1970: 1_792_598_400)
        )
    }

    static func medico(
        nombres: String = "Ana María", apellidos: String = "López Hernández", tipo: String = "Doctor",
        especialidad: String? = "Pediatría", area: String = "Emergencia"
    ) -> EstadoPublico.Medico {
        .init(
            nombres: nombres, apellidos: apellidos, tipo: tipo, especialidad: especialidad, area: area,
            horaInicio: "07:00:00", horaFin: "15:00:00"
        )
    }

    static func aviso(titulo: String = "Horario de visitas") -> EstadoPublico.AvisoPublico {
        .init(
            id: UUID(), titulo: titulo, contenido: "2:00–6:00 p. m.",
            fechaPublicacion: Date(timeIntervalSince1970: 1_792_000_000), fechaExpiracion: nil
        )
    }
}

/// iOS-C5 Información pública con `GET /api/publico/estado` (HUNI-76).
@MainActor
struct InformacionPublicaViewModelTests {
    let service = FakeEstadoPublicoService()

    @Test func muestraOcupacionAgregadaMedicosYAvisos() async {
        let viewModel = InformacionPublicaViewModel(service: service)
        #expect(!viewModel.cargado)

        await viewModel.cargar()

        #expect(viewModel.cargado)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.ocupacion.map(\.titulo) == ["VIP · 3.ª planta", "Semiprivadas · 2.ª planta"])
        #expect(viewModel.ocupacion.map(\.resumen) == ["3/5 ocupadas", "11/12 ocupadas"])
        #expect(viewModel.ocupacion.map(\.detalle) == ["2 camas disponibles", "1 cama disponible"])
        #expect(viewModel.ocupacion.allSatisfy { $0.progreso <= 1 })
        #expect(viewModel.ocupacionTotal?.resumen == "14/17 ocupadas")
        #expect(viewModel.medicosDeTurno == [
            MedicoDeTurno(nombre: "Ana María López Hernández", especialidad: "Pediatría", area: "Emergencia", horario: "07:00–15:00"),
        ])
        #expect(viewModel.avisos.map(\.titulo) == ["Horario de visitas"])
        #expect(viewModel.actualizado == "Actualizado a las 10:00")
    }

    @Test func sinEspecialidadMuestraElTipoDePersonal() async {
        service.result = .success(InformacionPublicaFixtures.estado(medicos: [
            InformacionPublicaFixtures.medico(tipo: "Médico de emergencia", especialidad: nil),
        ]))
        let viewModel = InformacionPublicaViewModel(service: service)

        await viewModel.cargar()

        #expect(viewModel.medicosDeTurno.first?.especialidad == "Médico de emergencia")
    }

    @Test func vacioSinMedicosNiAvisos() async {
        service.result = .success(InformacionPublicaFixtures.estado(medicos: [], avisos: []))
        let viewModel = InformacionPublicaViewModel(service: service)
        #expect(!viewModel.sinMedicos, "Antes de cargar no se muestra el vacío")

        await viewModel.cargar()

        #expect(viewModel.sinMedicos)
        #expect(viewModel.sinAvisos)
        #expect(viewModel.ocupacion.count == 2)
    }

    @Test func errorSinDatosConReintentar() async {
        service.result = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        let viewModel = InformacionPublicaViewModel(service: service)

        await viewModel.cargar()

        #expect(viewModel.errorSinDatos == InformacionPublicaViewModel.mensajeError)
        #expect(viewModel.errorRecarga == nil)
        #expect(!viewModel.isLoading)

        service.result = .success(InformacionPublicaFixtures.estado())
        await viewModel.cargar()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.medicosDeTurno.count == 1)
        #expect(service.llamadas == 2)
    }

    @Test func sinInternetLoDice() async {
        service.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = InformacionPublicaViewModel(service: service)

        await viewModel.cargar()

        #expect(viewModel.errorSinDatos == "No hay conexión. Revisa tu internet e intenta de nuevo.")
    }

    @Test func unaRecargaFallidaConservaLosDatos() async {
        let viewModel = InformacionPublicaViewModel(service: service)
        await viewModel.cargar()

        service.result = .failure(APIError(statusCode: 502, code: "HTTP_502"))
        await viewModel.cargar()

        #expect(viewModel.errorSinDatos == nil)
        #expect(viewModel.errorRecarga == InformacionPublicaViewModel.mensajeError)
        #expect(viewModel.medicosDeTurno.count == 1)
        #expect(viewModel.ocupacion.count == 2)
    }

    // MARK: API

    @Test func pideElEstadoPublicoSinTokenYDecodifica() async throws {
        let body = Data(Self.estadoEnvelope.utf8)
        let session = MockURLProtocol.session { _ in (200, body) }
        // Aunque hubiera sesión, el endpoint público no manda el JWT.
        let client = APIClient(baseURL: URL(string: "http://localhost:3000/api"), session: session) { "jwt" }

        let estado = try await APIEstadoPublicoService(client: client).estado()

        let request = try #require(MockURLProtocol.requests(of: session).first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://localhost:3000/api/publico/estado")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(estado.ocupacion.total.total == 17)
        #expect(estado.ocupacion.vip.disponibles == 2)
        #expect(estado.medicosDeTurno.first?.apellidos == "López Hernández")
        #expect(estado.medicosDeTurno.first?.especialidad == nil)
        #expect(estado.medicosDeTurno.first?.horaInicio == "19:00:00")
        #expect(estado.avisos.first?.titulo == "Jornada de vacunación")
        #expect(estado.avisos.first?.fechaExpiracion == nil)
    }

    @Test func sinURLBaseFallaSinRed() async {
        let service = APIEstadoPublicoService(client: APIClient(baseURL: nil) { nil })

        await #expect(throws: APIClientError.self) {
            _ = try await service.estado()
        }
    }

    private static let estadoEnvelope = """
    {"statusCode":200,"success":true,"message":"Estado público","data":{
      "ocupacion":{
        "vip":{"ocupadas":3,"disponibles":2,"total":5},
        "semiprivada":{"ocupadas":9,"disponibles":3,"total":12},
        "total":{"ocupadas":12,"disponibles":5,"total":17}},
      "medicos_de_turno":[{"nombres":"Ana María","apellidos":"López Hernández","tipo":"Médico de emergencia",
        "especialidad":null,"area":"Emergencia","hora_inicio":"19:00:00","hora_fin":"07:00:00"}],
      "avisos":[{"id":"11111111-1111-4111-8111-000000000001","titulo":"Jornada de vacunación",
        "contenido":"Sábado de 8:00 a 12:00.","fecha_publicacion":"2026-11-10T14:00:00.000Z","fecha_expiracion":null}],
      "actualizado_en":"2026-11-17T16:32:10.123Z"}}
    """
}
