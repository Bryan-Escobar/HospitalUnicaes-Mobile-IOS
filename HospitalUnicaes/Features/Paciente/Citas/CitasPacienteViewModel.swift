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

/// iOS-P2 Mis citas. Datos de ejemplo hasta conectar las citas del paciente.
@MainActor
@Observable
final class CitasPacienteViewModel {
    var segmento: CitasSegmento = .proximas
    var isSolicitando = false
    private(set) var solicitudes: [SolicitudCita]
    private let citas: [CitaPaciente]
    private let hoy: Date

    init(hoy: Date = Date(), citas: [CitaPaciente]? = nil, solicitudes: [SolicitudCita] = [PacienteMuestra.solicitud]) {
        self.hoy = hoy
        self.citas = citas ?? PacienteMuestra.citas(hoy: hoy)
        self.solicitudes = solicitudes
    }

    var proximas: [CitaPaciente] {
        citas.filter { $0.fecha >= hoy }.sorted { $0.fecha < $1.fecha }
    }

    var pasadas: [CitaPaciente] {
        citas.filter { $0.fecha < hoy }.sorted { $0.fecha > $1.fecha }
    }

    var visibles: [CitaPaciente] {
        segmento == .proximas ? proximas : pasadas
    }

    /// La solicitud queda "Enviada" hasta que recepción la convierta en cita.
    func agregar(_ solicitud: SolicitudCita) {
        solicitudes.insert(solicitud, at: 0)
        segmento = .proximas
    }
}
