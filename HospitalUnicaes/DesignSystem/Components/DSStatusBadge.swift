import SwiftUI

/// Estados de dominio con su badge (handoff §4.2). Los textos son exactos a las reglas del
/// `context.md`: el estado siempre se lee como texto + icono, nunca solo como color.
struct DSStatus: Identifiable {
    /// Dominio para VoiceOver: "Ambulancia, estado En Servicio".
    let domain: String
    let title: String
    /// SF Symbol del estado; `nil` si el diseño no lleva icono (cita programada).
    let systemImage: String?
    let tone: DSTone

    var id: String { "\(domain)·\(title)" }
}

extension DSStatus {
    // Laboratorio: Pendiente → En Proceso → Completado
    static let labPendiente = DSStatus(domain: "Laboratorio", title: "Pendiente", systemImage: "clock", tone: .warning)
    static let labEnProceso = DSStatus(
        domain: "Laboratorio", title: "En Proceso", systemImage: "circle.lefthalf.filled", tone: .info
    )
    static let labCompletado = DSStatus(domain: "Laboratorio", title: "Completado", systemImage: "checkmark", tone: .success)

    // Ambulancia
    static let ambulanciaDisponible = DSStatus(
        domain: "Ambulancia", title: "Disponible", systemImage: "checkmark", tone: .success
    )
    static let ambulanciaEnServicio = DSStatus(
        domain: "Ambulancia", title: "En Servicio", systemImage: "arrow.right", tone: .danger
    )
    static let ambulanciaEnMantenimiento = DSStatus(
        domain: "Ambulancia", title: "En Mantenimiento", systemImage: "pause", tone: .neutral
    )

    // Cama
    static let camaLibre = DSStatus(domain: "Cama", title: "Libre", systemImage: "circle", tone: .success)
    static let camaOcupada = DSStatus(domain: "Cama", title: "Ocupada", systemImage: "circle.fill", tone: .occupied)
    static let camaElegida = DSStatus(domain: "Cama", title: "Elegida", systemImage: "checkmark", tone: .selected)

    // Cita
    static let citaProgramada = DSStatus(domain: "Cita", title: "Programada", systemImage: nil, tone: .info)
    static let citaAtendida = DSStatus(domain: "Cita", title: "Atendida", systemImage: "checkmark", tone: .success)
    static let citaCancelada = DSStatus(domain: "Cita", title: "Cancelada", systemImage: "xmark", tone: .neutral)

    // Solicitud de cita o ambulancia
    static let solicitudEnviada = DSStatus(domain: "Solicitud", title: "Enviada", systemImage: "circle", tone: .warning)
    static let solicitudRechazada = DSStatus(domain: "Solicitud", title: "Rechazada", systemImage: "xmark", tone: .neutral)

    // Bitácora, inventario, avisos y turnos
    static let bitacoraFinalizado = DSStatus(domain: "Servicio", title: "Finalizado", systemImage: "checkmark", tone: .success)
    static let stockBajo = DSStatus(
        domain: "Inventario", title: "Stock bajo", systemImage: "exclamationmark.triangle", tone: .warning
    )
    static let avisoVigente = DSStatus(domain: "Aviso", title: "Vigente", systemImage: "circle.fill", tone: .success)
    static let avisoProgramado = DSStatus(domain: "Aviso", title: "Programado", systemImage: "clock", tone: .info)
    static let avisoVencido = DSStatus(domain: "Aviso", title: "Vencido", systemImage: "xmark", tone: .neutral)
    static let turnoEnCurso = DSStatus(domain: "Turno", title: "En curso", systemImage: "circle.fill", tone: .accent)

    /// Todos los estados, para catálogos y previews.
    static let allCases: [DSStatus] = [
        labPendiente, labEnProceso, labCompletado,
        ambulanciaDisponible, ambulanciaEnServicio, ambulanciaEnMantenimiento,
        camaLibre, camaOcupada, camaElegida,
        citaProgramada, citaAtendida, citaCancelada,
        solicitudEnviada, solicitudRechazada,
        bitacoraFinalizado, stockBajo,
        avisoVigente, avisoProgramado, avisoVencido,
        turnoEnCurso,
    ]
}

enum DSBadgeSize {
    /// Texto 13/600, icono 13.
    case regular
    /// Texto 15/700 (KPI de ambulancia).
    case large
}

enum DSBadgeAppearance {
    /// Colores del tono del estado.
    case standard
    /// Badge blanco sobre la tarjeta destacada teal (texto en el color claro del tono).
    case onAccent
}

/// Badge de estado en píldora (handoff §5.1): padding 3/9/3/7, gap 5.
struct DSStatusBadge: View {
    private let status: DSStatus
    private let size: DSBadgeSize
    private let appearance: DSBadgeAppearance

    @Environment(\.colorScheme) private var colorScheme

    init(_ status: DSStatus, size: DSBadgeSize = .regular, appearance: DSBadgeAppearance = .standard) {
        self.status = status
        self.size = size
        self.appearance = appearance
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage = status.systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .fontWeight(.bold)
            }
            Text(status.title)
        }
        .font(size == .regular ? DSFont.badge : DSFont.badgeLarge)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(foreground)
        .padding(.leading, status.systemImage == nil ? 9 : 7)
        .padding(.trailing, 9)
        .padding(.vertical, size == .regular ? 3 : 5)
        .background(background, in: Capsule())
        .overlay {
            Capsule().strokeBorder(border, lineWidth: 1)
        }
        // Sobre la tarjeta teal el badge es blanco en ambos modos: se fuerzan los colores claros del tono.
        .environment(\.colorScheme, appearance == .onAccent ? .light : colorScheme)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.domain), estado \(status.title)")
    }

    private var foreground: Color {
        status.tone.foreground
    }

    private var background: Color {
        appearance == .onAccent ? .white : status.tone.background
    }

    private var border: Color {
        appearance == .onAccent ? .white : status.tone.border
    }
}

// MARK: - Previews

private struct DSStatusBadgePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
                ForEach(DSStatus.allCases) { status in
                    HStack {
                        Text(status.domain)
                            .font(DSFont.bodySecondary)
                            .foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        DSStatusBadge(status)
                    }
                }
                Text("Grande")
                    .font(DSFont.subtitle)
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(.top, DSSpacing.small)
                HStack {
                    DSStatusBadge(.ambulanciaDisponible, size: .large)
                    DSStatusBadge(.ambulanciaEnServicio, size: .large)
                }
            }
            .padding(DSSpacing.regular)
        }
        .background(DSColor.background)
    }
}

#Preview("Badges de estado") {
    DSStatusBadgePreview()
}

#Preview("Badges · oscuro") {
    DSStatusBadgePreview()
        .preferredColorScheme(.dark)
}

#Preview("Badges · texto grande") {
    DSStatusBadgePreview()
        .dynamicTypeSize(.accessibility2)
}
