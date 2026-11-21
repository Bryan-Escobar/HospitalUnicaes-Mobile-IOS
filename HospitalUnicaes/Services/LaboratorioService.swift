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

protocol LaboratorioService: ResultadoArchivoURLService {
    func examenes() async throws -> [ExamenCatalogo]
    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada
    func orden(id: UUID) async throws -> OrdenLaboratorioPaciente
}

struct APILaboratorioService: LaboratorioService {
    let client: APIClient

    func examenes() async throws -> [ExamenCatalogo] {
        try await client.send(.get, "laboratorio/examenes")
    }

    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada {
        try await client.send(.post, "laboratorio/ordenes", body: body)
    }

    func orden(id: UUID) async throws -> OrdenLaboratorioPaciente {
        try await client.send(.get, "laboratorio/ordenes/\(id.uuidString.lowercased())")
    }

    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado {
        let orden = ordenId.uuidString.lowercased()
        let examen = examenId.uuidString.lowercased()
        return try await client.send(.get, "laboratorio/ordenes/\(orden)/examenes/\(examen)/resultado/archivo")
    }
}
