import Foundation

/// Avisos del hospital vistos por el paciente (HUNI-74 en la API). La API ya filtra por la sesión:
/// un paciente solo recibe avisos públicos y por defecto solo los vigentes.
protocol AvisosService: Sendable {
    /// El aviso vigente más reciente, o `nil` si no hay ninguno.
    func vigente() async throws -> Aviso?
}

/// Aviso tal como lo devuelve `GET /avisos`.
struct AvisoPublicado: Decodable, Hashable {
    let id: UUID
    let titulo: String
    let contenido: String

    var aviso: Aviso { Aviso(titulo: titulo, detalle: contenido) }
}

struct APIAvisosService: AvisosService {
    let client: APIClient

    func vigente() async throws -> Aviso? {
        let pagina: Pagina<AvisoPublicado> = try await client.send(
            .get,
            "avisos",
            query: [
                URLQueryItem(name: "pagina", value: "1"),
                URLQueryItem(name: "por_pagina", value: "1"),
                URLQueryItem(name: "vigencia", value: "vigentes"),
            ]
        )
        return pagina.items.first?.aviso
    }
}
