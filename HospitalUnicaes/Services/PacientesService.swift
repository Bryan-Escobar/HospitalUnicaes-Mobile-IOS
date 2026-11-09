import Foundation

protocol PacientesService: Sendable {
    func pacientes(buscar: String?, pagina: Int, porPagina: Int) async throws -> Pagina<Paciente>
    func historial(pacienteId: UUID) async throws -> HistorialClinico
}

struct APIPacientesService: PacientesService {
    let client: APIClient

    func pacientes(buscar: String?, pagina: Int, porPagina: Int) async throws -> Pagina<Paciente> {
        var query = [
            URLQueryItem(name: "pagina", value: String(pagina)),
            URLQueryItem(name: "por_pagina", value: String(porPagina)),
        ]
        if let buscar {
            query.append(URLQueryItem(name: "buscar", value: buscar))
        }
        return try await client.send(.get, "pacientes", query: query)
    }

    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        try await client.send(.get, "pacientes/\(pacienteId.uuidString.lowercased())/historial")
    }
}
