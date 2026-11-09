import SwiftUI

/// Tipografía iOS (handoff §4.4): SF Pro sobre los estilos de texto del sistema,
/// así todos los tamaños escalan con Dynamic Type.
///
/// | Token | Estilo base | Tamaño/interlínea | Peso |
/// |---|---|---|---|
/// | `largeTitle` | `.largeTitle` | 34/41 | Bold |
/// | `title` | `.title2` | 22/28 | Semibold |
/// | `subtitle` | `.headline` | 17/22 | Semibold |
/// | `body` | `.body` | 17/22 | Regular |
/// | `bodySecondary` | `.subheadline` | 15/20 | Regular |
/// | `footnote` | `.footnote` | 13/18 | Regular |
enum DSFont {
    static let largeTitle = Font.system(.largeTitle, weight: .bold)
    static let title = Font.system(.title2, weight: .semibold)
    static let subtitle = Font.system(.headline, weight: .semibold)
    static let body = Font.system(.body)
    static let bodyEmphasis = Font.system(.body, weight: .semibold)
    static let bodySecondary = Font.system(.subheadline)
    static let bodySecondaryEmphasis = Font.system(.subheadline, weight: .semibold)
    static let footnote = Font.system(.footnote)
    static let footnoteEmphasis = Font.system(.footnote, weight: .semibold)

    /// Etiqueta de campo de texto (13/600).
    static let fieldLabel = footnoteEmphasis
    /// Texto de botón grande (17/600).
    static let button = bodyEmphasis
    /// Texto de botón compacto dentro de tarjetas (15/600).
    static let buttonCompact = bodySecondaryEmphasis
    /// Texto de badge normal (13/600).
    static let badge = footnoteEmphasis
    /// Texto de badge grande, KPI de ambulancia (15/700).
    static let badgeLarge = Font.system(.subheadline, weight: .bold)
}

extension View {
    /// Rótulo en mayúsculas de la tarjeta destacada ("PRÓXIMA CITA"): 13/600, tracking .04em.
    func dsEyebrow() -> some View {
        font(DSFont.footnoteEmphasis)
            .textCase(.uppercase)
            .tracking(0.52)
    }
}

#Preview("Tipografía") {
    VStack(alignment: .leading, spacing: DSSpacing.medium) {
        Text("Mis citas").font(DSFont.largeTitle)
        Text("Próxima cita").font(DSFont.title)
        Text("Dra. Ana Rivas · Alergista").font(DSFont.subtitle)
        Text("Recepción revisará tu solicitud.").font(DSFont.body)
        Text("Hemograma completo").font(DSFont.bodySecondary)
        Text("Actualizado hace 5 s").font(DSFont.footnote)
        Text("Próxima cita").dsEyebrow()
    }
    .foregroundStyle(DSColor.textPrimary)
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DSColor.background)
}
