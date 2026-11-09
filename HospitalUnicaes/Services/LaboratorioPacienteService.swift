import Foundation

/// Laboratorio visto por el paciente (HUNI-62). La API filtra por la sesión: con rol paciente
/// solo devuelve sus órdenes, así que nunca se manda `paciente_id`.
protocol LaboratorioPacienteService: Sendable {
    /// `GET laboratorio/ordenes`, todas las páginas.
    func misOrdenes() async throws -> [OrdenLaboratorioPaciente]
    /// `GET laboratorio/ordenes/{ordenId}/examenes/{examenId}/resultado/archivo`.
    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado
}

struct APILaboratorioPacienteService: LaboratorioPacienteService {
    let client: APIClient
    /// Máximo que acepta la API.
    var porPagina = 100

    func misOrdenes() async throws -> [OrdenLaboratorioPaciente] {
        var ordenes: [OrdenLaboratorioPaciente] = []
        var pagina = 1
        while true {
            let resultado: Pagina<OrdenLaboratorioPaciente> = try await client.send(
                .get,
                "laboratorio/ordenes",
                query: [
                    URLQueryItem(name: "pagina", value: String(pagina)),
                    URLQueryItem(name: "por_pagina", value: String(porPagina)),
                ]
            )
            ordenes += resultado.items
            guard pagina < resultado.paginacion.totalPaginas else { return ordenes }
            pagina += 1
        }
    }

    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado {
        let orden = ordenId.uuidString.lowercased()
        let examen = examenId.uuidString.lowercased()
        return try await client.send(.get, "laboratorio/ordenes/\(orden)/examenes/\(examen)/resultado/archivo")
    }
}
