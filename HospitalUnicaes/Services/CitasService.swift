import Foundation
import Supabase

protocol CitasService: Sendable {
    /// Citas del doctor de la sesión con `fecha_hora` en [desde, hasta). El RLS de `v_citas` ya filtra por doctor.
    func citas(desde: Date, hasta: Date) async throws -> [Cita]
    /// Una cita por id (`nil` si ya no es visible). La usa el detalle para refrescar el estado.
    func cita(id: UUID) async throws -> Cita?
}

struct SupabaseCitasService: CitasService {
    let client: SupabaseClient?

    func citas(desde: Date, hasta: Date) async throws -> [Cita] {
        let rows: [Cita] = try await fetch(
            client?
                .from("v_citas")
                .select()
                .gte("fecha_hora", value: desde.ISO8601Format())
                .lt("fecha_hora", value: hasta.ISO8601Format())
                .order("fecha_hora", ascending: true)
        )
        return rows
    }

    func cita(id: UUID) async throws -> Cita? {
        let rows: [Cita] = try await fetch(
            client?
                .from("v_citas")
                .select()
                .eq("id", value: id)
                .limit(1)
        )
        return rows.first
    }

    private func fetch<T: Decodable>(_ query: PostgrestTransformBuilder?) async throws -> T {
        guard let query else { throw APIClientError.missingBaseURL }
        do {
            return try await query.execute().value
        } catch {
            throw Self.mapped(error)
        }
    }

    /// El mensaje de PostgREST llega como "CODIGO: detalle". Nos quedamos con el código.
    private static func mapped(_ error: Error) -> Error {
        guard let postgrest = error as? PostgrestError else { return error }
        let prefix = postgrest.message.split(separator: ":", maxSplits: 1).first
        let code = prefix.map { String($0).trimmed } ?? ""
        let status = postgrest.code == "PGRST301" ? 401 : 400
        return APIError(statusCode: status, code: code.isEmpty ? "POSTGREST" : code)
    }
}
