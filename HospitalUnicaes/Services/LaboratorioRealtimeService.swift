import Foundation
import Supabase

/// Evento del canal de laboratorio. No trae la fila: solo avisa que hay que recargar por la API,
/// que es la que decide qué ve el paciente.
enum EventoLaboratorio: Equatable, Sendable {
    /// `.live` al quedar suscrito, `.reconnecting` al caer, `.offline` sin cliente.
    case conexion(DSLiveIndicator.Status)
    /// INSERT/UPDATE/DELETE en `orden_examenes`.
    case examenCambio
}

protocol LaboratorioRealtimeService: Sendable {
    /// Se suscribe al empezar a iterar y quita el canal cuando la iteración termina
    /// (al cancelar la `Task` que lo consume).
    func eventos() -> AsyncStream<EventoLaboratorio>
}

/// Supabase Realtime (`postgres_changes`) sobre `orden_examenes`. Crear una orden inserta sus
/// exámenes; iniciar uno o registrar su resultado actualiza su `estado`. La RLS
/// (`puede_ver_orden`) limita los eventos a las órdenes del propio paciente.
struct SupabaseLaboratorioRealtimeService: LaboratorioRealtimeService {
    let client: SupabaseClient?

    func eventos() -> AsyncStream<EventoLaboratorio> {
        let (stream, continuation) = AsyncStream<EventoLaboratorio>.makeStream()
        guard let client else {
            continuation.yield(.conexion(.offline))
            continuation.finish()
            return stream
        }

        let channel = client.channel("laboratorio-paciente-\(UUID().uuidString)")
        let cambios = channel.postgresChange(AnyAction.self, schema: "public", table: "orden_examenes")
        let estados = channel.statusChange

        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await estado in estados {
                        continuation.yield(.conexion(estado == .subscribed ? .live : .reconnecting))
                    }
                }
                group.addTask {
                    for await _ in cambios {
                        continuation.yield(.examenCambio)
                    }
                }
                group.addTask {
                    do {
                        try await channel.subscribeWithError()
                    } catch {
                        continuation.yield(.conexion(.reconnecting))
                    }
                }
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
            Task { await client.removeChannel(channel) }
        }
        return stream
    }
}
