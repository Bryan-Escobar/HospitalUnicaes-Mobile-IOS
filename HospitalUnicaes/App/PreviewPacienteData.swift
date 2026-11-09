#if DEBUG
import Foundation

extension PacienteDependencies {
    /// Ambulancia disponible y sin solicitudes, sin red ni GPS reales.
    static var preview: PacienteDependencies { preview() }

    static func preview(
        estado: EstadoAmbulancia = .disponible,
        solicitud: SolicitudAmbulancia? = nil
    ) -> PacienteDependencies {
        PacienteDependencies(
            ambulancias: PreviewAmbulanciaService(estadoInicial: estado, solicitudInicial: solicitud),
            ambulanciaRealtime: PreviewAmbulanciaRealtime(),
            ubicacion: { PreviewUbicacionService() }
        )
    }
}

enum PacientePreviewData {
    static let ambulanciaId = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000001") ?? UUID()

    static func ambulancia(_ estado: EstadoAmbulancia) -> Ambulancia {
        Ambulancia(id: ambulanciaId, placa: "AMB-001", estado: estado, updatedAt: Date(), solicitudActiva: nil)
    }

    /// Solicitud de las 10:12 por dolor de pecho, como en el Figma.
    static func solicitud(_ estado: EstadoSolicitudAmbulancia) -> SolicitudAmbulancia {
        let enviada = Formatting.fecha(Date(), hora: 10, minuto: 12)
        let despachada = estado == .pendiente ? nil : Formatting.fecha(Date(), hora: 10, minuto: 14)
        return SolicitudAmbulancia(
            id: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000002") ?? UUID(),
            estado: estado, tipoEmergencia: .cardiaca, descripcionEmergencia: nil,
            direccionOrigen: "Col. Escalón, San Salvador", latitud: 13.6929, longitud: -89.2182, precisionM: 20,
            destino: nil, fechaSolicitud: enviada, fechaDespacho: despachada,
            fechaEnCurso: estado == .enCurso ? Formatting.fecha(Date(), hora: 10, minuto: 20) : nil,
            fechaCierre: estado == .finalizada || estado == .cancelada ? Formatting.fecha(Date(), hora: 11, minuto: 2) : nil,
            notasCierre: nil, motivoCancelacion: estado == .cancelada ? "Solicitud duplicada" : nil
        )
    }
}

struct PreviewAmbulanciaService: AmbulanciaService {
    let estadoInicial: EstadoAmbulancia
    let solicitudInicial: SolicitudAmbulancia?

    func estado() async throws -> Ambulancia { PacientePreviewData.ambulancia(estadoInicial) }
    func ultimaSolicitud() async throws -> SolicitudAmbulancia? { solicitudInicial }

    func solicitud(id: UUID) async throws -> SolicitudAmbulancia {
        solicitudInicial ?? PacientePreviewData.solicitud(.pendiente)
    }

    func solicitar(_ nueva: NuevaSolicitudAmbulancia) async throws -> SolicitudAmbulancia {
        PacientePreviewData.solicitud(.pendiente)
    }
}

/// Siempre "En vivo" y sin eventos.
struct PreviewAmbulanciaRealtime: AmbulanciaRealtimeService {
    func eventos() -> AsyncStream<EventoAmbulancia> {
        AsyncStream { continuation in
            continuation.yield(.conexion(.live))
        }
    }
}

@MainActor
final class PreviewUbicacionService: UbicacionService {
    var autorizacion: EstadoPermisoUbicacion { .permitido }

    func ubicacionActual() async throws -> Ubicacion {
        Ubicacion(latitud: 13.6929, longitud: -89.2182, precisionM: 20, direccion: "Col. Escalón, San Salvador")
    }
}
#endif
