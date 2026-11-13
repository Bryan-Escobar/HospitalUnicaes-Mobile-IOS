import Foundation
import Supabase

protocol CitasPacienteService: Sendable {
    /// Citas del paciente de la sesión (el RLS de `v_citas` solo devuelve las suyas), de la más nueva a la más vieja.
    func citas() async throws -> [Cita]
    /// Sus solicitudes de atención más recientes.
    func solicitudes() async throws -> [SolicitudAtencion]
    func especialidades() async throws -> [Especialidad]
    /// Crea la solicitud con `crear_solicitud_atencion()`; recepción la ve en su bandeja.
    func enviar(_ solicitud: NuevaSolicitudAtencion) async throws -> SolicitudAtencion
}

/// Citas y solicitudes de atención directo desde Supabase (HUNI-51, HUNI-56).
struct SupabaseCitasPacienteService: CitasPacienteService {
    let client: SupabaseClient?

    func citas() async throws -> [Cita] {
        try await ejecutar { client in
            try await client.from("v_citas").select().order("fecha_hora", ascending: false).limit(100).execute().value
        }
    }

    func solicitudes() async throws -> [SolicitudAtencion] {
        try await ejecutar { client in
            try await client.from("v_solicitudes_atencion").select()
                .order("created_at", ascending: false).limit(20).execute().value
        }
    }

    func especialidades() async throws -> [Especialidad] {
        try await ejecutar { client in
            try await client.from("especialidades").select("id, nombre").order("nombre").execute().value
        }
    }

    func enviar(_ solicitud: NuevaSolicitudAtencion) async throws -> SolicitudAtencion {
        try await ejecutar { client in
            // La RPC devuelve la fila de la tabla (sin nombre de especialidad); se relee de la vista.
            struct Creada: Decodable { let id: UUID }
            let creada: Creada = try await client.rpc("crear_solicitud_atencion", params: solicitud).single().execute().value
            return try await client.from("v_solicitudes_atencion").select()
                .eq("id", value: creada.id).single().execute().value
        }
    }

    private func ejecutar<T>(_ consulta: (SupabaseClient) async throws -> T) async throws -> T {
        guard let client else { throw APIClientError.missingBaseURL }
        do {
            return try await consulta(client)
        } catch let error as PostgrestError {
            throw Self.mapped(error)
        }
    }

    /// PostgREST manda "CODIGO: detalle"; el detalle de las reglas de negocio ya viene redactado para el paciente.
    static func mapped(_ error: PostgrestError) -> APIError {
        mapped(code: error.code, message: error.message)
    }

    static func mapped(code sqlstate: String?, message: String) -> APIError {
        let partes = message.split(separator: ":", maxSplits: 1).map { String($0).trimmed }
        let codigo = partes.count == 2 && partes[0].allSatisfy { $0.isUppercase || $0 == "_" } ? partes[0] : "POSTGREST"
        let detalle = partes.count == 2 ? partes[1].prefix(1).uppercased() + partes[1].dropFirst() : ""
        let status: Int
        switch sqlstate {
        case "PGRST301": status = 401
        case "42501": status = 403
        case "PT409": status = 409
        case "PT422": status = 422
        default: status = 400
        }
        return APIError(statusCode: status, code: codigo, message: detalle)
    }
}
