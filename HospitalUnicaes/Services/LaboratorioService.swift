import Foundation

struct CrearOrdenRequest: Encodable, Equatable {
    let consultaId: UUID
    var prioridad = "normal"
    let indicaciones: String?
    let examenIds: [UUID]
}

struct OrdenCreada: Decodable, Equatable {
    let id: UUID
    let estado: String
}

struct ExamenCatalogo: Decodable, Equatable, Identifiable, Hashable {
    let id: UUID
    let nombre: String
    let categoria: String?
    let tipoMuestra: String?
}

protocol LaboratorioService: Sendable {
    func examenes() async throws -> [ExamenCatalogo]
    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada
}

struct APILaboratorioService: LaboratorioService {
    let client: APIClient

    func examenes() async throws -> [ExamenCatalogo] {
        try await client.send(.get, "laboratorio/examenes")
    }

    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada {
        try await client.send(.post, "laboratorio/ordenes", body: body)
    }
}
