import SwiftUI

/// Indicador de conexión en tiempo real (handoff §4.3), clave en la demo sincrónica.
struct DSLiveIndicator: View {
    enum Status {
        case live
        case reconnecting
        case offline

        var title: String {
            switch self {
            case .live: "En vivo"
            case .reconnecting: "Reconectando…"
            case .offline: "Sin conexión"
            }
        }

        var tone: DSTone {
            switch self {
            case .live: .accent
            case .reconnecting: .warning
            case .offline: .offline
            }
        }
    }

    private let state: Status
    private let isCompact: Bool

    /// - Parameter isCompact: padding 5/10 (encabezado de Inicio) en lugar de 6/12.
    init(_ state: Status, isCompact: Bool = false) {
        self.state = state
        self.isCompact = isCompact
    }

    var body: some View {
        HStack(spacing: 6) {
            marker
            Text(state.title)
        }
        .font(DSFont.footnoteEmphasis)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(state.tone.foreground)
        .padding(.vertical, isCompact ? 5 : 6)
        .padding(.horizontal, isCompact ? 10 : 12)
        .background(state.tone.background, in: Capsule())
        .overlay {
            Capsule().strokeBorder(state.tone.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Conexión en tiempo real: \(state.title)")
    }

    @ViewBuilder
    private var marker: some View {
        switch state {
        case .live:
            // Punto de 8 pt con halo de 3 pt.
            Circle()
                .fill(DSColor.action)
                .frame(width: 8, height: 8)
                .padding(3)
                .background(state.tone.border, in: Circle())
        case .reconnecting:
            Circle()
                .strokeBorder(state.tone.foreground, lineWidth: 2)
                .frame(width: 8, height: 8)
        case .offline:
            Image(systemName: "xmark")
                .imageScale(.small)
                .fontWeight(.bold)
        }
    }
}

#Preview("Indicador en vivo") {
    VStack(spacing: DSSpacing.medium) {
        DSLiveIndicator(.live)
        DSLiveIndicator(.live, isCompact: true)
        DSLiveIndicator(.reconnecting)
        DSLiveIndicator(.offline)
        VStack(spacing: DSSpacing.medium) {
            DSLiveIndicator(.live)
            DSLiveIndicator(.reconnecting)
            DSLiveIndicator(.offline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DSColor.background)
        .environment(\.colorScheme, .dark)
    }
    .padding()
    .background(DSColor.background)
}
