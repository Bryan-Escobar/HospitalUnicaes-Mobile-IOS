import Foundation
@testable import HospitalUnicaes

final class FakeLaboratorioPacienteService: LaboratorioPacienteService, @unchecked Sendable {
    var ordenesResult: Result<[OrdenLaboratorioPaciente], Error> = .success([])
    /// URL firmada por llamada; si se acaban, repite la última.
    var archivoResults: [Result<ArchivoFirmado, Error>] = [.success(LabFixtures.archivoFirmado())]
    /// Pausa de `misOrdenes()` para probar el coalescido.
    var demora: Duration?
    private(set) var llamadasOrdenes = 0
    private(set) var llamadasArchivo = 0

    func misOrdenes() async throws -> [OrdenLaboratorioPaciente] {
        llamadasOrdenes += 1
        if let demora { try? await Task.sleep(for: demora) }
        return try ordenesResult.get()
    }

    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado {
        let indice = min(llamadasArchivo, archivoResults.count - 1)
        llamadasArchivo += 1
        return try archivoResults[indice].get()
    }
}

/// Canal en memoria: la prueba empuja eventos con `enviar`.
final class FakeLaboratorioRealtime: LaboratorioRealtimeService, @unchecked Sendable {
    private var continuation: AsyncStream<EventoLaboratorio>.Continuation?
    private(set) var suscripciones = 0

    func eventos() -> AsyncStream<EventoLaboratorio> {
        let (stream, continuation) = AsyncStream<EventoLaboratorio>.makeStream()
        self.continuation = continuation
        suscripciones += 1
        return stream
    }

    func enviar(_ evento: EventoLaboratorio) {
        continuation?.yield(evento)
    }

    func terminar() {
        continuation?.finish()
    }
}

final class FakeResultadoArchivoService: ResultadoArchivoService, @unchecked Sendable {
    /// Resultado por llamada; si se acaban, repite el último.
    var results: [Result<URL, Error>] = [.success(LabFixtures.pdfLocal())]
    var demora: Duration?
    private(set) var descargas: [(url: URL, nombre: String)] = []
    private(set) var borrados: [URL?] = []

    func descargar(_ url: URL, nombreArchivo: String) async throws -> URL {
        let indice = min(descargas.count, results.count - 1)
        descargas.append((url, nombreArchivo))
        if let demora { try? await Task.sleep(for: demora) }
        return try results[indice].get()
    }

    func borrar(_ local: URL?) {
        borrados.append(local)
    }
}

enum LabFixtures {
    static let ordenId = UUID(uuidString: "11111111-1111-4111-8111-000000000001") ?? UUID()
    static let hemogramaId = UUID(uuidString: "22222222-2222-4222-8222-000000000001") ?? UUID()
    static let quimicaId = UUID(uuidString: "22222222-2222-4222-8222-000000000002") ?? UUID()

    static let doctor = DoctorResumen(id: UUID(), nombres: "Ana", apellidos: "Rivas", especialidad: nil)

    static func resultado(tieneArchivo: Bool = true) -> ResultadoExamen {
        ResultadoExamen(
            id: UUID(), valor: "13.5", unidad: "g/dL", rangoReferencia: "12.0 - 15.5", observaciones: nil,
            tieneArchivo: tieneArchivo, fechaResultado: Date(timeIntervalSince1970: 1_760_600_000)
        )
    }

    static func examen(
        id: UUID = hemogramaId,
        nombre: String = "Hemograma completo",
        estado: EstadoLaboratorio,
        completado: Date? = nil,
        tieneArchivo: Bool = true
    ) -> OrdenExamenPaciente {
        OrdenExamenPaciente(
            id: id,
            examen: .init(id: UUID(), nombre: nombre, tipoMuestra: "Sangre"),
            estado: estado,
            fechaInicio: estado == .pendiente ? nil : Date(timeIntervalSince1970: 1_760_500_000),
            fechaCompletado: estado == .completado ? completado ?? Date(timeIntervalSince1970: 1_760_600_000) : nil,
            resultado: estado == .completado ? resultado(tieneArchivo: tieneArchivo) : nil
        )
    }

    static func orden(
        id: UUID = ordenId,
        fecha: Date = Date(timeIntervalSince1970: 1_760_400_000),
        examenes: [OrdenExamenPaciente]
    ) -> OrdenLaboratorioPaciente {
        OrdenLaboratorioPaciente(
            id: id, fechaSolicitud: fecha, prioridad: .normal, estado: .pendiente,
            doctor: doctor, indicaciones: nil, examenes: examenes
        )
    }

    static func fila(estado: EstadoLaboratorio, tieneArchivo: Bool = true) -> ExamenLaboratorioPaciente {
        orden(examenes: [examen(estado: estado, tieneArchivo: tieneArchivo)]).filas[0]
    }

    static func archivoFirmado() -> ArchivoFirmado {
        ArchivoFirmado(
            url: URL(string: "https://storage.example.test/firmado.pdf?token=abc") ?? URL(fileURLWithPath: "/"),
            expiraEn: Date().addingTimeInterval(600)
        )
    }

    /// PDF mínimo de una página en un temporal, para miniatura y tamaño.
    static func pdfLocal() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(UUID().uuidString).pdf")
        let pdf = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >> endobj
        trailer << /Root 1 0 R >>
        %%EOF
        """
        try? Data(pdf.utf8).write(to: url)
        return url
    }
}
