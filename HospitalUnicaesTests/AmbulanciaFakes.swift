import Foundation
@testable import HospitalUnicaes

final class FakeAmbulanciaService: AmbulanciaService, @unchecked Sendable {
    var estadoResult: Result<Ambulancia, Error> = .success(AmbulanciaFixtures.ambulancia(.disponible))
    var ultimaResult: Result<SolicitudAmbulancia?, Error> = .success(nil)
    var solicitudResult: Result<SolicitudAmbulancia, Error> = .success(AmbulanciaFixtures.solicitud(.pendiente))
    var solicitarResult: Result<SolicitudAmbulancia, Error> = .success(AmbulanciaFixtures.solicitud(.pendiente))
    /// Pausa `solicitar` para comprobar que no hay doble envío.
    var demoraSolicitar: Duration = .zero
    private(set) var llamadasEstado = 0
    private(set) var llamadasUltima = 0
    private(set) var idsSolicitud: [UUID] = []
    private(set) var enviadas: [NuevaSolicitudAmbulancia] = []

    func estado() async throws -> Ambulancia {
        llamadasEstado += 1
        return try estadoResult.get()
    }

    func ultimaSolicitud() async throws -> SolicitudAmbulancia? {
        llamadasUltima += 1
        return try ultimaResult.get()
    }

    func solicitud(id: UUID) async throws -> SolicitudAmbulancia {
        idsSolicitud.append(id)
        return try solicitudResult.get()
    }

    func solicitar(_ nueva: NuevaSolicitudAmbulancia) async throws -> SolicitudAmbulancia {
        enviadas.append(nueva)
        if demoraSolicitar > .zero { try await Task.sleep(for: demoraSolicitar) }
        return try solicitarResult.get()
    }
}

/// El test empuja eventos con `enviar`; el stream sigue abierto hasta que se cancela la Task.
final class FakeAmbulanciaRealtime: AmbulanciaRealtimeService, @unchecked Sendable {
    private var continuation: AsyncStream<EventoAmbulancia>.Continuation?

    var suscrito: Bool { continuation != nil }

    func eventos() -> AsyncStream<EventoAmbulancia> {
        let (stream, continuation) = AsyncStream<EventoAmbulancia>.makeStream()
        self.continuation = continuation
        return stream
    }

    func enviar(_ evento: EventoAmbulancia) {
        continuation?.yield(evento)
    }
}

@MainActor
final class FakeUbicacionService: UbicacionService {
    var result: Result<Ubicacion, Error> = .success(AmbulanciaFixtures.ubicacion)
    var autorizacion: EstadoPermisoUbicacion = .permitido

    func ubicacionActual() async throws -> Ubicacion {
        try result.get()
    }
}

enum AmbulanciaFixtures {
    static let solicitudId = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000002") ?? UUID()
    /// Lunes 9 nov 2026, 10:12 en El Salvador.
    static let enviada = Date(timeIntervalSince1970: 1_794_240_720)

    static let ubicacion = Ubicacion(
        latitud: 13.6929, longitud: -89.2182, precisionM: 20, direccion: "Col. Escalón, San Salvador"
    )

    static func ambulancia(_ estado: EstadoAmbulancia) -> Ambulancia {
        Ambulancia(id: UUID(), placa: "AMB-001", estado: estado, updatedAt: enviada, solicitudActiva: nil)
    }

    static func solicitud(
        _ estado: EstadoSolicitudAmbulancia,
        despacho: Date? = nil,
        cierre: Date? = nil,
        motivo: String? = nil
    ) -> SolicitudAmbulancia {
        SolicitudAmbulancia(
            id: solicitudId, estado: estado, tipoEmergencia: .cardiaca, descripcionEmergencia: nil,
            direccionOrigen: "Col. Escalón, San Salvador", latitud: nil, longitud: nil, precisionM: nil,
            destino: nil, fechaSolicitud: enviada, fechaDespacho: despacho, fechaEnCurso: nil,
            fechaCierre: cierre, notasCierre: nil, motivoCancelacion: motivo
        )
    }
}
