import SwiftUI

enum DSCardStyle {
    /// Fondo blanco, borde 1 `neutral/200`, sin sombra.
    case standard
    /// Fondo teal y texto blanco ("Próxima cita").
    case highlighted
}

/// Tarjeta contenedora (handoff §5.1): radio 18, padding 14/16. Crece en alto con Dynamic Type.
///
/// ```swift
/// DSCard(style: .highlighted) {
///     Text("Próxima cita").dsEyebrow()
///     Text("Jueves 22 oct · 10:30").font(DSFont.title)
/// }
/// ```
struct DSCard<Content: View>: View {
    private let style: DSCardStyle
    private let spacing: CGFloat
    private let content: Content

    init(
        style: DSCardStyle = .standard,
        spacing: CGFloat = DSSpacing.small,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .foregroundStyle(style == .highlighted ? DSColor.onAction : DSColor.textPrimary)
        .dsCardBackground(style)
    }
}

extension View {
    /// Aplica fondo, borde y radio de tarjeta a una vista existente (sin padding).
    func dsCardBackground(_ style: DSCardStyle = .standard) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
        return background(style == .highlighted ? DSColor.action : DSColor.surface, in: shape)
            .overlay {
                if style == .standard {
                    shape.strokeBorder(DSColor.border, lineWidth: 1)
                }
            }
    }
}

// MARK: - Previews

private struct DSCardPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                DSCard(style: .highlighted) {
                    Text("Próxima cita")
                        .dsEyebrow()
                        .opacity(0.9)
                    Text("Jueves 22 oct · 10:30")
                        .font(DSFont.title)
                    HStack {
                        Text("Dra. Ana Rivas · Alergista")
                            .font(DSFont.bodySecondary)
                        Spacer()
                        DSStatusBadge(.citaProgramada, appearance: .onAccent)
                    }
                }

                DSCard {
                    HStack {
                        Text("Últimos resultados").font(DSFont.subtitle)
                        Spacer()
                        Button("Ver todos") {}
                            .font(DSFont.bodySecondary)
                            .foregroundStyle(DSColor.tint)
                    }
                    Rectangle()
                        .fill(DSColor.border)
                        .frame(height: 1)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hemograma completo").font(DSFont.bodySecondaryEmphasis)
                            Text("Dr. Carlos Molina · 20 oct")
                                .font(DSFont.footnote)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                        Spacer()
                        DSStatusBadge(.labCompletado)
                    }
                }

                DSCard {
                    HStack {
                        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                            Text("Ambulancia").font(DSFont.subtitle)
                            DSStatusBadge(.ambulanciaDisponible)
                        }
                        Spacer()
                        DSButton(
                            "Solicitar",
                            systemImage: "light.beacon.max",
                            kind: .destructive,
                            size: .compact,
                            isFullWidth: false
                        ) {}
                    }
                }
            }
            .padding(DSSpacing.regular)
        }
        .background(DSColor.backgroundGrouped)
    }
}

#Preview("Tarjetas") {
    DSCardPreview()
}

#Preview("Tarjetas · oscuro + texto grande") {
    DSCardPreview()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility1)
}
