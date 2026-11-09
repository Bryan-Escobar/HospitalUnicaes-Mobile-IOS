import Foundation

/// Ambulancia del paciente (HUNI-70). La API aplica la privacidad: un paciente solo ve
/// el estado de la ambulancia y sus propias solicitudes.
protocol AmbulanciaService: Sendable {
    /// `GET /ambulancia`.
    func estado() async throws -> Ambulancia
    /// La solicitud más reciente del paciente (`nil` si nunca pidió una).
    func ultimaSolicitud() async throws -> SolicitudAmbulancia?
    /// `GET /ambulancia/solicitudes/{id}`.
    func solicitud(id: UUID) async throws -> SolicitudAmbulancia
    /// `POST /ambulancia/solicitudes`.
    func solicitar(_ nueva: NuevaSolicitudAmbulancia) async throws -> SolicitudAmbulancia
}

struct APIAmbulanciaService: AmbulanciaService {
    let client: APIClient

    func estado() async throws -> Ambulancia {
        try await client.send(.get, "ambulancia")
    }

    func ultimaSolicitud() async throws -> SolicitudAmbulancia? {
        let pagina: Pagina<SolicitudAmbulancia> = try await client.send(
            .get,
            "ambulancia/solicitudes",
            query: [URLQueryItem(name: "pagina", value: "1"), URLQueryItem(name: "por_pagina", value: "1")]
        )
        return pagina.items.first
    }

    func solicitud(id: UUID) async throws -> SolicitudAmbulancia {
        try await client.send(.get, "ambulancia/solicitudes/\(id.uuidString.lowercased())")
    }

    func solicitar(_ nueva: NuevaSolicitudAmbulancia) async throws -> SolicitudAmbulancia {
        try await client.send(.post, "ambulancia/solicitudes", body: nueva)
    }
}
