import Foundation
import Supabase

protocol TurnosService: Sendable {
    /// Turnos del empleado con sesión que empiezan entre `desde` y `hasta` (días civiles, ambos incluidos).
    /// Vacío si la cuenta no tiene registro de personal.
    func misTurnos(desde: Date, hasta: Date) async throws -> [TurnoPersonal]
}

/// Lee `v_turnos` de Supabase (HUNI-51). La vista la ve todo usuario con sesión, así que se filtra por
/// `personal_actual_id()`, la función que resuelve el empleado de la sesión en la base.
struct SupabaseTurnosService: TurnosService {
    let client: SupabaseClient?

    func misTurnos(desde: Date, hasta: Date) async throws -> [TurnoPersonal] {
        guard let client else { throw APIClientError.missingBaseURL }
        do {
            let personalId: UUID? = try await client.rpc("personal_actual_id").execute().value
            guard let personalId else { return [] }
            return try await client
                .from("v_turnos")
                .select()
                .eq("personal_id", value: personalId)
                .gte("fecha", value: Self.dia(desde))
                .lte("fecha", value: Self.dia(hasta))
                .order("inicio", ascending: true)
                .execute()
                .value
        } catch let error as PostgrestError {
            let status = error.code == "PGRST301" ? 401 : 400
            throw APIError(statusCode: status, code: "POSTGREST")
        }
    }

    /// `2026-11-13` en hora de El Salvador, el formato de la columna `fecha`.
    static func dia(_ date: Date) -> String {
        let partes = Formatting.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", partes.year ?? 0, partes.month ?? 0, partes.day ?? 0)
    }
}
