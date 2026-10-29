import SwiftUI

extension EstadoCita {
    var status: DSStatus {
        switch self {
        case .programada, .desconocido: .citaProgramada
        case .confirmada: .citaConfirmada
        case .atendida: .citaAtendida
        case .cancelada: .citaCancelada
        case .noAsistio: .citaNoAsistio
        }
    }
}

extension EstadoLaboratorio {
    var status: DSStatus {
        switch self {
        case .pendiente, .desconocido: .labPendiente
        case .enProceso: .labEnProceso
        case .completado: .labCompletado
        }
    }
}

/// Badge de una consulta que todavía no se cierra. No entra al catálogo del design system.
enum ConsultaEstadoVisual {
    static let abierta = DSStatus(domain: "Consulta", title: "Abierta", systemImage: "circle", tone: .info)
}
