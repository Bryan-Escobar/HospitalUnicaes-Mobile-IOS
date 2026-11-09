import Foundation
@testable import HospitalUnicaes

final class CallSink: @unchecked Sendable {
    private(set) var calls: [String] = []
    func add(_ name: String) { calls.append(name) }
}

final class FakeConsultasService: ConsultasService, @unchecked Sendable {
    private(set) var calls: [String] = []
    private var counts: [String: Int] = [:]
    var failCall: (name: String, nth: Int)?
    var error: Error = APIError(statusCode: 500, code: "HTTP_500")
    var sink: CallSink?
    private(set) var consultas: [CrearConsultaRequest] = []
    private(set) var recetas: [CrearRecetaRequest] = []
    private(set) var ordenes: [CrearOrdenRequest] = []

    func crearConsulta(_ body: CrearConsultaRequest) async throws -> ConsultaCreada {
        try gate("crearConsulta")
        consultas.append(body)
        return ConsultaCreada(id: UUID(), citaId: body.citaId, cerradaEn: nil)
    }

    func agregarDiagnostico(consultaId: UUID, _ body: CrearDiagnosticoRequest) async throws -> RegistroCreado {
        try gate("agregarDiagnostico")
        return RegistroCreado(id: UUID())
    }

    func emitirReceta(consultaId: UUID, _ body: CrearRecetaRequest) async throws -> RegistroCreado {
        try gate("emitirReceta")
        recetas.append(body)
        return RegistroCreado(id: UUID())
    }

    func cerrarConsulta(id: UUID) async throws -> ConsultaCreada {
        try gate("cerrarConsulta")
        return ConsultaCreada(id: id, citaId: nil, cerradaEn: "2026-10-25T16:00:00Z")
    }

    private func gate(_ name: String) throws {
        counts[name, default: 0] += 1
        calls.append(name)
        sink?.add(name)
        if let failCall, failCall.name == name, counts[name] == failCall.nth {
            throw error
        }
    }
}

final class FakeLaboratorioService: LaboratorioService, @unchecked Sendable {
    var examenesResult: Result<[ExamenCatalogo], Error> = .success([])
    var failCall: (name: String, nth: Int)?
    var error: Error = APIError(statusCode: 500, code: "HTTP_500")
    var sink: CallSink?
    private(set) var calls: [String] = []
    private var counts: [String: Int] = [:]
    private(set) var ordenes: [CrearOrdenRequest] = []

    func examenes() async throws -> [ExamenCatalogo] {
        try gate("examenes")
        return try examenesResult.get()
    }

    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada {
        try gate("crearOrden")
        ordenes.append(body)
        return OrdenCreada(id: UUID(), estado: "pendiente")
    }

    private func gate(_ name: String) throws {
        counts[name, default: 0] += 1
        calls.append(name)
        sink?.add(name)
        if let failCall, failCall.name == name, counts[name] == failCall.nth {
            throw error
        }
    }
}
