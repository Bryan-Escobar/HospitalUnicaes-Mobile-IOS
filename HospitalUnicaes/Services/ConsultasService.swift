import Foundation

struct CrearConsultaRequest: Encodable, Equatable {
    let pacienteId: UUID
    let citaId: UUID?
    let motivoConsulta: String?
    let notas: String?
}

struct CrearDiagnosticoRequest: Encodable, Equatable {
    let descripcion: String
    var tipo = "principal"
}

struct CrearRecetaRequest: Encodable, Equatable {
    struct Detalle: Encodable, Equatable {
        let medicamento: String
        let dosis: String?
        let frecuencia: String?
        let duracion: String?
    }

    let indicaciones: String?
    let detalles: [Detalle]
}

struct ConsultaCreada: Decodable, Equatable {
    let id: UUID
    let citaId: UUID?
    let cerradaEn: String?
}

struct RegistroCreado: Decodable, Equatable {
    let id: UUID
}

protocol ConsultasService: Sendable {
    func crearConsulta(_ body: CrearConsultaRequest) async throws -> ConsultaCreada
    func agregarDiagnostico(consultaId: UUID, _ body: CrearDiagnosticoRequest) async throws -> RegistroCreado
    func emitirReceta(consultaId: UUID, _ body: CrearRecetaRequest) async throws -> RegistroCreado
    func cerrarConsulta(id: UUID) async throws -> ConsultaCreada
}

struct APIConsultasService: ConsultasService {
    let client: APIClient

    func crearConsulta(_ body: CrearConsultaRequest) async throws -> ConsultaCreada {
        try await client.send(.post, "consultas", body: body)
    }

    func agregarDiagnostico(consultaId: UUID, _ body: CrearDiagnosticoRequest) async throws -> RegistroCreado {
        try await client.send(.post, ruta(consultaId, "diagnosticos"), body: body)
    }

    func emitirReceta(consultaId: UUID, _ body: CrearRecetaRequest) async throws -> RegistroCreado {
        try await client.send(.post, ruta(consultaId, "recetas"), body: body)
    }

    func cerrarConsulta(id: UUID) async throws -> ConsultaCreada {
        try await client.send(.post, ruta(id, "cerrar"), body: String?.none)
    }

    private func ruta(_ id: UUID, _ accion: String) -> String {
        "consultas/\(id.uuidString.lowercased())/\(accion)"
    }
}
