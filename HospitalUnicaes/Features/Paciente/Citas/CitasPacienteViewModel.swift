import Foundation
import Observation

enum CitasSegmento: String, CaseIterable, Identifiable {
    case proximas
    case pasadas

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .proximas: "Próximas"
        case .pasadas: "Pasadas"
        }
    }
}

/// iOS-P2 Mis citas (HUNI-56). Citas de `v_citas` (el RLS solo devuelve las del paciente) y sus solicitudes
/// de atención: las pendientes y las rechazadas de las últimas dos semanas, con la respuesta de recepción.
@MainActor
@Observable
final class CitasPacienteViewModel {
    private let service: any CitasPacienteService
    private let hoy: () -> Date
    private var carga = UUID()

    var segmento: CitasSegmento = .proximas
    var isSolicitando = false
    private(set) var citas: [CitaPaciente] = []
    private(set) var todasLasSolicitudes: [SolicitudAtencion] = []
    private(set) var cargado = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(service: any CitasPacienteService, hoy: @escaping () -> Date = Date.init) {
        self.service = service
        self.hoy = hoy
    }

    /// Programadas o confirmadas que todavía no pasan, de la más cercana a la más lejana.
    var proximas: [CitaPaciente] {
        let ahora = hoy()
        return citas.filter { Self.activa($0) && $0.fecha >= ahora }.sorted { $0.fecha < $1.fecha }
    }

    /// El resto (pasadas, atendidas, canceladas), de la más reciente a la más vieja.
    var pasadas: [CitaPaciente] {
        let ahora = hoy()
        return citas.filter { !(Self.activa($0) && $0.fecha >= ahora) }.sorted { $0.fecha > $1.fecha }
    }

    var visibles: [CitaPaciente] {
        segmento == .proximas ? proximas : pasadas
    }

    /// Pendientes y rechazadas recientes; las atendidas ya aparecen como cita.
    var solicitudes: [SolicitudAtencion] {
        let limite = Formatting.sumarDias(-14, a: hoy())
        return todasLasSolicitudes.filter {
            $0.estado == .pendiente || ($0.estado == .rechazada && ($0.respondidaEn ?? $0.createdAt) >= limite)
        }
    }

    var estaVacio: Bool { cargado && errorMessage == nil && visibles.isEmpty }

    func cargar() async {
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil
        do {
            async let citas = service.citas()
            async let solicitudes = service.solicitudes()
            let (listaCitas, listaSolicitudes) = try await (citas, solicitudes)
            guard carga == token else { return }
            self.citas = listaCitas.map(CitaPaciente.init)
            todasLasSolicitudes = listaSolicitudes
            cargado = true
            isLoading = false
        } catch {
            guard carga == token else { return }
            errorMessage = "No se pudieron cargar tus citas."
            isLoading = false
        }
    }

    /// La solicitud recién enviada va arriba mientras la lista se refresca.
    func agregar(_ solicitud: SolicitudAtencion) {
        todasLasSolicitudes.removeAll { $0.id == solicitud.id }
        todasLasSolicitudes.insert(solicitud, at: 0)
        segmento = .proximas
    }

    private static func activa(_ cita: CitaPaciente) -> Bool {
        cita.estado == .programada || cita.estado == .confirmada
    }
}
