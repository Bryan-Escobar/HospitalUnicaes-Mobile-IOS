import Foundation
import Supabase

/// Evento del canal de tiempo real. No trae la fila: solo avisa qué recargar por la API,
/// que es la que decide qué ve el paciente.
enum EventoAmbulancia: Equatable, Sendable {
    /// `.live` al quedar suscrito, `.reconnecting` al caer, `.offline` sin cliente.
    case conexion(DSLiveIndicator.Status)
    /// UPDATE en `ambulancias`.
    case ambulanciaCambio
    /// INSERT/UPDATE en `solicitudes_ambulancia` (id de la fila, si viene).
    case solicitudCambio(UUID?)
}

protocol AmbulanciaRealtimeService: Sendable {
    /// Se suscribe al empezar a iterar y quita el canal cuando la iteración termina
    /// (al cancelar la `Task` que lo consume).
    func eventos() -> AsyncStream<EventoAmbulancia>
}

/// Supabase Realtime (`postgres_changes`) sobre `ambulancias` y `solicitudes_ambulancia`.
/// La RLS limita los eventos de solicitudes a las del propio paciente.
struct SupabaseAmbulanciaRealtimeService: AmbulanciaRealtimeService {
    let client: SupabaseClient?

    func eventos() -> AsyncStream<EventoAmbulancia> {
        let (stream, continuation) = AsyncStream<EventoAmbulancia>.makeStream()
        guard let client else {
            continuation.yield(.conexion(.offline))
            continuation.finish()
            return stream
        }

        let channel = client.channel("ambulancia-paciente-\(UUID().uuidString)")
        let ambulancias = channel.postgresChange(UpdateAction.self, schema: "public", table: "ambulancias")
        let solicitudes = channel.postgresChange(AnyAction.self, schema: "public", table: "solicitudes_ambulancia")
        let estados = channel.statusChange

        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await estado in estados {
                        continuation.yield(.conexion(estado == .subscribed ? .live : .reconnecting))
                    }
                }
                group.addTask {
                    for await _ in ambulancias {
                        continuation.yield(.ambulanciaCambio)
                    }
                }
                group.addTask {
                    for await accion in solicitudes {
                        continuation.yield(.solicitudCambio(Self.id(de: accion)))
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

    private static func id(de accion: AnyAction) -> UUID? {
        let fila: JSONObject
        switch accion {
        case let .insert(insert): fila = insert.record
        case let .update(update): fila = update.record
        case let .delete(delete): fila = delete.oldRecord
        }
        return fila["id"]?.stringValue.flatMap(UUID.init(uuidString:))
    }
}
