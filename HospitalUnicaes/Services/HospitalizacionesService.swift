import Foundation

protocol HospitalizacionesService: Sendable {
    /// Hospitalización activa del paciente, o `nil`. Lista vacía, 404 (HUNI-66) y 403 no lanzan.
    func activa(pacienteId: UUID) async throws -> Hospitalizacion?
}

struct APIHospitalizacionesService: HospitalizacionesService {
    let client: APIClient

    func activa(pacienteId: UUID) async throws -> Hospitalizacion? {
        do {
            let pagina: Pagina<Hospitalizacion> = try await client.send(
                .get,
                "hospitalizaciones",
                query: [
                    URLQueryItem(name: "paciente_id", value: pacienteId.uuidString.lowercased()),
                    URLQueryItem(name: "estado", value: "activa"),
                    URLQueryItem(name: "por_pagina", value: "1"),
                ]
            )
            return pagina.items.first
        } catch let error as APIError where error.statusCode == 404 || error.statusCode == 403 {
            return nil
        } catch let error as APIError where error.code == "RUTA_NO_ENCONTRADA" || error.code == "ACCESO_DENEGADO" {
            return nil
        }
    }
}
