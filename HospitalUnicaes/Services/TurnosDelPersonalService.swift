import Foundation
import Supabase

/// Turnos del personal que consulta el paciente (HUNI-76, "consulta de turnos").
protocol TurnosDelPersonalService: Sendable {
    /// Turnos de todo el personal que empiezan entre `desde` y `hasta` (días civiles, ambos incluidos).
    func turnos(desde: Date, hasta: Date) async throws -> [TurnoDelPersonal]
}

/// Lee `v_turnos` de Supabase (HUNI-51). La vista la puede leer cualquier usuario con sesión (RLS por
/// `rol_actual()`); aquí se piden solo las columnas públicas del turno (`TurnoDelPersonal.columnas`).
struct SupabaseTurnosDelPersonalService: TurnosDelPersonalService {
    let client: SupabaseClient?

    func turnos(desde: Date, hasta: Date) async throws -> [TurnoDelPersonal] {
        guard let client else { throw APIClientError.missingBaseURL }
        do {
            return try await client
                .from("v_turnos")
                .select(TurnoDelPersonal.columnas)
                .gte("fecha", value: Formatting.diaISO(desde))
                .lte("fecha", value: Formatting.diaISO(hasta))
                .order("inicio", ascending: true)
                .execute()
                .value
        } catch let error as PostgrestError {
            let status = error.code == "PGRST301" ? 401 : 400
            throw APIError(statusCode: status, code: "POSTGREST")
        }
    }
}
